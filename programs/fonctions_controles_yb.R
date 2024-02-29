library(tidyverse)

####################################
### Fonctions pour les controles ###
####################################

## Pour les fichiers des imputations
ctrl_tot_imp <- function(x){
  ctrl_0 <- x %>% 
    filter(prediction == 0) %>%
    mutate(siren_0 = length(unique(siren))) %>% 
    distinct(period, siren_0)
  if (nrow(ctrl_0) == 0){
    ctrl_0 <- data.frame(period = unique(x$period), 
                         siren_0 = 0)
  }

  ctrl_tot <- x %>% 
    mutate(siren_imp = length(unique(siren)),
           siren_dup = sum(table(imput_intro$siren)-1),
           imputation = sum(prediction)) %>% 
    distinct(period, siren_imp, siren_dup, imputation) %>% 
    inner_join(ctrl_0, by = "period") %>%
    relocate(period, siren_imp, siren_0,
             siren_dup, imputation)
  
  return(as.data.frame(ctrl_tot))
}

ctrl_class_imp <- function(x){
  ctrl_split <- x %>% 
    mutate(tranche = ifelse(prediction == 0, "1 - Pas d'imputation", ""),
           tranche = ifelse(prediction > 0 & prediction < 10000,
                            "2 - Moins de 10 000", tranche),
           tranche = ifelse(prediction >= 10000 & prediction < 100000,
                            "3 - Entre 10 000 et 100 000", tranche),
           tranche = ifelse(prediction >= 100000 & prediction < 1000000,
                            "4 - Entre 100 000 et 1 million", tranche),
           tranche = ifelse(prediction >= 1000000 & prediction < 10000000,
                            "5 - Entre 1 million et 10 millions", tranche),
           tranche = ifelse(prediction >= 10000000,
                            "6 - 10 millions ou plus", tranche)) %>% 
    group_by(tranche) %>% 
    mutate(siren_pred = length(unique(siren)),
           imputation = sum(prediction)) %>% 
    distinct(tranche, siren_pred, imputation) %>% 
    arrange(tranche)
  
  sum_siren <- sum(ctrl_split$siren_pred)
  sum_imput <- sum(ctrl_split$imputation)
  
  ctrl_split2 <- ctrl_split %>%
    mutate(tranche = substr(tranche,5, 50),
           part_siren = siren_pred/sum_siren,
           part_imput = imputation/sum_imput)
  
  return(as.data.frame(ctrl_split2))
}

list_seuil_pred <- function(x, seuil){
  list10M <- x %>% 
    filter(prediction >= seuil) %>% 
    distinct(period, siren, prediction) %>% 
    arrange(period, desc(prediction))
  
  return(list10M)
}

ctrl_method_imp <- function(x){
  ctrl_meth0 <- x %>% 
    filter(prediction == 0) %>% 
    group_by(method) %>% 
    mutate(siren_0 = length(unique(siren))) %>% 
    distinct(method, siren_0)
  
  ctrl_meth <- x %>% 
    group_by(method) %>% 
    mutate(siren_pred = length(unique(siren)),
           imputation = sum(prediction)) %>%
    left_join(ctrl_meth0, by = "method") %>%
    distinct(method, siren_pred, siren_0, imputation)

  ctrl_meth[is.na(ctrl_meth$siren_0), "siren_0"] <- 0
  sum_siren <- length(unique(x$siren))
  sum_imput <- sum(x$prediction)
  
  ctrl_meth <- ctrl_meth %>%
    mutate(part_siren = (siren_pred+siren_0)/sum_siren,
           part_imput = imputation/sum_imput)
  
  return(as.data.frame(ctrl_meth))
}


## Pour les fichiers des ventilations
ctrl_siren_ventil <- function(x){
  ctrl_0 <- x %>% 
    filter(dist_prediction == 0 | is.na(dist_prediction)) %>%
    mutate(siren_0 = 0) %>% 
    group_by(period) %>% 
    mutate(siren_0 = length(unique(siren))) %>% 
    distinct(period, siren_0)
  
  ctrl_dup <- x %>% 
    group_by(period, siren) %>% 
    mutate(tot_ratio = round(sum(ratio), digits = 2),
           dup_ratio = ifelse(tot_ratio <= 1,0,1)) %>% 
    filter(dup_ratio == 1) %>% 
    group_by(period) %>% 
    mutate(siren_dup = length(unique(siren))) %>% 
    distinct(period, siren_dup)
  
  ctrl_ratio <- x %>% 
    group_by(period, siren) %>% 
    mutate(tot_ratio = sum(ratio)) %>% 
    group_by(period) %>% 
    mutate(min_ratio = min(tot_ratio),
           max_ratio = max(tot_ratio)) %>% 
    distinct(period, min_ratio, max_ratio)
  
  ctrl_tot <- x %>% 
    group_by(period) %>% 
    mutate(siren_ventil = length(unique(siren))) %>% 
    distinct(period, siren_ventil) %>% 
    left_join(ctrl_0, by = "period") %>% 
    left_join(ctrl_dup, by = "period") %>% 
    mutate(siren_0 = ifelse(is.na(siren_0),0,siren_0),
           siren_dup = ifelse(is.na(siren_dup),0,siren_dup)) %>% 
    left_join(ctrl_ratio, by = "period") %>%
    relocate(period, siren_ventil, siren_0,
             siren_dup, min_ratio, max_ratio)
  
  return(as.data.frame(ctrl_tot))
}

ctrl_nmctr_ventil <- function(x){
  ctrl_NA <- x %>% 
    filter(pyod == "NA") %>% 
    group_by(period) %>% 
    mutate(pyod_Namibie = length(pyod)) %>% 
    distinct(period, pyod_Namibie)
  
  ctrl_nc8 <- x %>% 
    filter(!(nc8 %in% list_nc82022$Nc8)) %>% 
    group_by(period) %>% 
    mutate(nb_old_nc8 = length(unique(nc8))) %>% 
    distinct(period, nb_old_nc8)
  
  ctrl_tot <- x %>% 
    group_by(period) %>% 
    mutate(nb_a129 = length(unique(a129)),
           nb_nc8 = length(unique(nc8)),
           nb_pyod = length(unique(pyod)),
           nb_payp = length(unique(payp))) %>% 
    distinct(period, nb_a129, nb_nc8, nb_pyod, nb_payp) %>% 
    left_join(ctrl_NA, by = "period") %>% 
    mutate(pyod_Namibie = ifelse(is.na(pyod_Namibie),0,pyod_Namibie)) %>% 
    left_join(ctrl_nc8, by = "period") %>% 
    relocate(period, nb_a129, nb_nc8, nb_old_nc8,
             nb_pyod, pyod_Namibie, nb_payp)
  
  return(as.data.frame(ctrl_tot))
}

ctrl_imp_ventil <- function(x){
  ctrl_imp <- x %>% 
    group_by(period) %>% 
    mutate(tot_imput = sum(dist_prediction, na.rm = TRUE),
           min_imput = min(dist_prediction),
           max_imput = max(dist_prediction),
           med_imput = median(dist_prediction, na.rm = TRUE),
           mean_imput = mean(dist_prediction, na.rm = TRUE)) %>% 
    distinct(period, tot_imput, min_imput,
             max_imput, med_imput, mean_imput) %>% 
    relocate(period, tot_imput, min_imput,
             max_imput, med_imput, mean_imput)
  
  return(as.data.frame(ctrl_imp))
}


### Pour les révisions des mois précédents
revis_lastm <- function(x, histo){
  rev <- x %>% 
    group_by(period)%>% 
    mutate(var = sum(dist_prediction)) %>% 
    distinct(period, var)
  
  colnames(rev)[2] <- paste0("chiffre_", format(as.Date(mstat),"%Y%m"))
  
  if(grepl(paste0("chiffre_", format(as.Date(mstat),"%Y%m")), 
           colnames(histo)[length(colnames(histo))])){
    tmp <- histo %>% 
      select(-c(paste0("chiffre_", format(as.Date(mstat),"%Y%m"))))
  }else{
    tmp <- histo
  }
  
  tmp <- as.data.frame(tmp)
  tmp <- tmp[,c(1, (length(tmp)-2) : (length(tmp)) )]
  rev <- tmp %>% 
    right_join(rev, by="period")
  
  rev <- as.data.frame(rev)
  
  dfcal <- rev %>% 
    select(-ncol(rev)) %>% 
    mutate(cale = NA) %>% 
    relocate(period, cale)
  
  rev_var <- rev[,-1] - dfcal[,-1] 
  rev_evo <- rev_var / dfcal[,-1]
  rev_var <- rev_var[-nrow(rev_var), -1]
  rev_var$period <- rev[-nrow(rev), "period"]
  colnames(rev_var) <- gsub("chiffre", "variation", colnames(rev_var))
  
  rev_evo <- rev_evo[-nrow(rev_evo), -1]
  rev_evo$period <- rev[-nrow(rev), "period"]
  colnames(rev_evo) <- gsub("chiffre", "evolution", colnames(rev_evo))
  
  result <- rev[-nrow(rev),] %>% 
    left_join(rev_var, by = "period") %>% 
    left_join(rev_evo, by = "period") %>% 
    mutate(Mois_stat = paste0(lubridate::month(as.Date(period), label=TRUE),
                                    "-",year(as.Date(period)))) %>% 
    select(-period) %>% 
    relocate(Mois_stat)
  
  return(result)
  
}

### Pour ajouter les données du mois en cours à l'histo
histo_m <- function(x, histo){
  rev <- x %>% 
    group_by(period)%>% 
    mutate(var = sum(dist_prediction)) %>% 
    distinct(period, var)
  
  colnames(rev)[2] <- paste0("chiffre_", lubridate::month(as.Date(mstat), label = TRUE))
  
  if(grepl(paste0("chiffre_", lubridate::month(as.Date(mstat), label = TRUE)), 
           colnames(histo)[length(colnames(histo))])){
    rev <- histo %>% 
      select(-c(paste0("chiffre_", lubridate::month(as.Date(mstat), label = TRUE)))) %>% 
      right_join(rev, by="period")
  }else{
    rev <- histo %>% 
      right_join(rev, by="period")
  }
  
  result <- as.data.frame(rev)
  
  return(result)
  
}

######################################
### Fonctions pour le fichier XLSX ###
######################################

# Fonction pour les titres
#-------------------------
# - sheet : la feuille Excel pour contenir le titre
# - rowIndex : numéro de la ligne pour contenir le titre 
# - title : texte du titre
# - titleStyle : l'objet style pour le titre
xlsx.addTitle<-function(sheet, rowIndex, title, titleStyle){
  rows <-createRow(sheet,rowIndex=rowIndex)
  sheetTitle <-createCell(rows, colIndex=1)
  setCellValue(sheetTitle[[1,1]], title)
  setCellStyle(sheetTitle[[1,1]], titleStyle)
}

# Fonction ajout onglet imputation
#---------------------------------
# - sheetName : Nom de l'onglet
# - fichName : Nom du fichier 
# - df1 : dataFrame tot_imp
# - df2 : dataFrame split_imp
# - df3 : dataFrame meth_imp
xlsx.addOngetImput <- function(sheetName, fichName, df1, df2, df3){
  
# onglet "Imputations -"
#-----------------------------
sheet <- createSheet(wb, sheetName = sheetName)

# Ajouter un titre
xlsx.addTitle(sheet, rowIndex=1, 
              title=paste0("Contrôle du fichier : ", fichName),
              titleStyle = TITLE_STYLE)

# Ajouter df1
xlsx.addTitle(sheet, rowIndex=3, 
              title="Total des imputations",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(df1, sheet, startRow=4, startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                           `4`=cs2, `5`=cs2))

# Ajouter df2
xlsx.addTitle(sheet, rowIndex=7, 
              title="Imputation par tranche",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(df2, sheet, startRow=8, startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`2`=cs2, `3`=cs2,
                           `4`=cs3, `5`=cs3))

# Ajouter df 3
xlsx.addTitle(sheet, rowIndex=16, 
              title="Imputation selon la méthode",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(df3, sheet, startRow=17, startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`2`=cs2, `3`=cs2,
                           `4`=cs2, `5`=cs3, `6`=cs3))

# Changer la largeur des colonnes
setColumnWidth(sheet, colIndex=c(1), colWidth=26)
setColumnWidth(sheet, colIndex=c(2:6), colWidth=15)

}

# Fonction ajout onglet ventilation
#----------------------------------
# - sheetName : Nom de l'onglet
# - fichName : Nom du fichier 
# - df1 : dataFrame siren_ventil
# - df2 : dataFrame nmctr_ventil
# - df3 : dataFrame imp_ventil
# - df4 : dataFrame list_x_pyod
# - df5 : dataFrame list_x_pyod

xlsx.addOngetVentil <- function(sheetName, fichName, df1, df2, df3, df4, df5){
  
  # onglet "Ventilation -"
  #-----------------------------
  sheet <- createSheet(wb, sheetName = sheetName)
  lg_start = -1
  
  # Changer la largeur des colonnes
  setColumnWidth(sheet, colIndex=c(1), colWidth=20)
  setColumnWidth(sheet, colIndex=c(2:7), colWidth=15)
  
  # Ajouter un titre
  lg_start = lg_start + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title=paste0("Contrôle du fichier : ", fichName),
                titleStyle = TITLE_STYLE)
  
  # Ajouter df1
  lg_start = lg_start + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des siren",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df1, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2))
  
  # Ajouter df2
  lg_start = lg_start + nrow(df1) + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des nomenclatures",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df2, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2, `7`=cs2))
  
  # Ajouter df3
  lg_start = lg_start + nrow(df2) + 2 
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des imputations",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df3, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2))
  
  if(!is.null(df4) & !is.null(df5)){
    # Ajouter df4
    lg_start = lg_start + nrow(df3) + 2
    xlsx.addTitle(sheet, 
                  rowIndex=lg_start,
                  title="Modalité problématique dans les variables PYOD et PAYP",
                  titleStyle = SUB_TITLE_STYLE)
    
    lg_start = lg_start + 1
    addDataFrame(df4, sheet, 
                 startRow=lg_start, 
                 startColumn=1, 
                 colnamesStyle = TABLE_COLNAMES_STYLE,
                 row.names = FALSE)
    
    addDataFrame(df5, sheet, 
                 startRow=lg_start, 
                 startColumn=3, 
                 colnamesStyle = TABLE_COLNAMES_STYLE,
                 row.names = FALSE)
  }
  
  
}

# Fonction ajout onglet ventilation 21 et 29
#-------------------------------------------
# - sheetName : Nom de l'onglet
# - fichName : Nom du fichier 
# - df1 : dataFrame siren_ventil
# - df2 : dataFrame nmctr_ventil
# - df3 : dataFrame imp_ventil


xlsx.addOngetVentil2 <- function(sheetName, fichName, df1, df2, df3){
  
  # onglet "Ventilation -"
  #-----------------------------
  sheet <- createSheet(wb, sheetName = sheetName)
  lg_start = -1
  
  # Changer la largeur des colonnes
  setColumnWidth(sheet, colIndex=c(1), colWidth=20)
  setColumnWidth(sheet, colIndex=c(2:7), colWidth=15)
  
  # Ajouter un titre
  lg_start = lg_start + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title=paste0("Contrôle du fichier : ", fichName),
                titleStyle = TITLE_STYLE)
  
  # Ajouter df1
  lg_start = lg_start + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des siren",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df1, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2))
  
  # Ajouter df2
  lg_start = lg_start + nrow(df1) + 2
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des nomenclatures",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df2, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2, `7`=cs2))
  
  # Ajouter df3
  lg_start = lg_start + nrow(df2) + 2 
  xlsx.addTitle(sheet, rowIndex=lg_start, 
                title="Contrôle des imputations",
                titleStyle = SUB_TITLE_STYLE)
  
  lg_start = lg_start + 1
  addDataFrame(df3, sheet, startRow=lg_start, startColumn=1, 
               colnamesStyle = TABLE_COLNAMES_STYLE,
               row.names = FALSE,
               colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                             `4`=cs2, `5`=cs2, `6`=cs2))
  
}


