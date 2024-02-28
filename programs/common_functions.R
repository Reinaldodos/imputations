pacman::p_load(tidyr, rlang)

#################
### READ FILE ###
#################

read_file <- function(data_file, rename_list = NULL, colClasses, period_filter = F, 
                      add_variable = F, variable_name = NULL){
  result <- data.frame()
  for (file in data_file$files){
    d <- read.delim(
      file = file.path(data_file[data_file$files == file,]$directory, file),
      encoding = data_file[data_file$files == file,]$encoding,
      sep = data_file[data_file$files == file,]$sep, 
      dec = data_file[data_file$files == file,]$dec, 
      na.strings = data_file[data_file$files == file,]$na_strings, 
      skip = data_file[data_file$files == file,]$skiprows,
      colClasses = colClasses
    ) %>%
      as_tibble() %>%
      rename_with(tolower) %>%
      rename(rename_list)
    if (period_filter){
      d <- subset(d,
                  subset = ((period >= data_file[data_file$files == file,]$start)
                            & (period <= data_file[data_file$files == file,]$end)))
    }
    if (add_variable){
      d <- mutate(d, 
                  !!variable_name := data_file[data_file$files == file,variable_name])
    }
    result <- rbind(
      result, 
      d)
  }
  return(result)
}

# echantillon <- read_file(data.frame(
#   directory = "Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/échantillon/échantillon 202201/datas",
#   files = "echantillon_actualise_2022_01-s4v2-pour stats.csv",
#   encoding = "UTF-8", sep = ";", dec = ",", na_strings = "", skiprows = 0, flux = "E"
#   ), rename_list = c('type_enquete' = 'type.d.enquête'), colClasses = Classes, add_variable = T, 
#   variable_name = "flux")

#####################
### CHECK QUALITY ###
#####################

# not_include <- data.frame(variable = c('pyod', 'payp', 'payp'), 
#                           value = c(NA, 'XI', 'GB'))
check_production <- function(data, not_include){
  for(var in unique(not_include$variable)){
    if(sum(data[,var] %in% not_include[not_include$variable == var,]$value) > 0){
      stop(sprintf("Les valeurs %s apparaissent dans %s.", 
                   not_include[not_include$variable == var,]$value %>% paste(collapse = ","),
                   var))
    }
  }
}

check_imputation <- function(data, siren_list, period, monthly_threshold = 2e9){
  if (length(unique(data$period)) != length(period)){
    stop("La liste de période est soit trop longue soit trop courte !")
  }else{
    if (!all(unique(data$period) == period)){
      stop("La liste de période ne correspond pas !")
    }
  }
  
  if (length(unique(data$siren)) != length(unique(siren_list))){
    stop("La liste de siren est soit trop longue soit trop courte !")
  }else{
    if (!all(sort(unique(data$siren)) == sort(unique(siren_list)))){
      stop("La liste de siren ne correspond pas !")
    }
  }
  
  if (sum(data$prediction, na.rm = T) > monthly_threshold){
    warning(sprintf("La prédiction totale est supérieure à %s.", 
                    formatC(monthly_threshold, format = "e", digits = 0)))
  }
}

check_ventilation <- function(imput_data, ventil_data, flow = "E", loss = 20){
  if (flow == "E"){
    if (sum(!is.na(ventil_data$dist_prediction) & is.na(ventil_data$pyod)) > 0){
      stop("A l'expédition, pyod ne peut pas être nul !")
    }
    
    if (sum(ventil_data$pyod %in% c('XU', 'GB')) > 0){
      stop("A l'expédition, pyod ne peut contenir ni 'XU' ni 'GB' !")
    }
  }
  if (flow == "I"){
    if (sum(!is.na(ventil_data$dist_prediction) & is.na(ventil_data$payp)) > 0){
      stop("A l'introduction, payp ne peut pas êtr nul !")
    }
    
    if (sum(ventil_data$payp %in% c('XU', 'GB')) > 0){
      stop("A l'introduction, payp ne peut contenir ni 'XU' ni 'GB !")
    }
  }
  
  check_ventil <- ventil_data %>% 
    group_by(siren, period) %>%
    summarise(sum_ratio = sum(ratio, na.rm = T), 
              check_diff_prediction = (!is.na(sum(dist_prediction)) & (sum(dist_prediction) - unique(prediction) > 1)),
              dist_prediction = sum(dist_prediction, na.rm = T))
  if (max(check_ventil$sum_ratio, na.rm = T) > 1){
    print(subset(check_ventil, subset = (sum_ratio > 1)))
    stop("La somme des ratios est supérieure à 1 !")
  } 
  if (any(check_ventil$check_diff_prediction)){
    print(subset(check_ventil, subset = check_diff_prediction))
    stop("La somme des montants distribués ne correspond pas à la valeur prédite !")
  }
  
  if (length(unique(imput_data$siren)) != length(unique(ventil_data$siren))){
    stop("Les listes de siren de ventil_data et imput_data ne correspondent pas !")
  }
  
  check_ventil_imput <- full_join(check_ventil[,c("siren", "period", "dist_prediction")], 
                                  imput_data[,c("siren", "period", "prediction")], 
                                  by = c("siren", "period")) %>%
    group_by(period) %>%
    summarise(dist_prediction = sum(dist_prediction, na.rm = T), 
              prediction = sum(prediction, na.rm = T)) %>%
    mutate(check_loss = (prediction - dist_prediction)/prediction*100)
  if (any(check_ventil_imput$check_loss < 0)){
    print(check_ventil_imput)
    stop("La somme du fichier ventilation est supérieure que celle du fichier imputation !")
  }
  
  if (any(check_ventil_imput$check_loss > loss)){
    print(check_ventil_imput)
    warning("La perte liée aux entrants est trop importante !")
  }
  
}

auto_check_ventilation <- function(imput_files, ventil_file, classes, directory, flow = "E", loss = 20){
  imputation <- data.frame()
  for (file in imput_files){
    imputation <- rbind(imputation, 
                        read.csv2(
                          file = file.path(directory, file), 
                          colClasses = classes, 
                          na.strings = "") %>%
                          as_tibble())
  }
  imputation <- imputation %>%
    group_by(siren, period) %>%
    summarise(prediction = sum(prediction, na.rm = T))
  
  ventilation <- read.csv2(
    file = file.path(directory, ventil_file), 
    colClasses = classes, 
    na.strings = ""
  ) %>%
    as_tibble()
  
  check_ventilation(imput_data = imputation, ventil_data = ventilation, 
                    flow = flow, loss = loss)
}