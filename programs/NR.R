pacman::p_load(tidyverse,
               lubridate,
               doParallel,
               rlang,
               zoo,
               multidplyr,
               data.table,
               tsbox,
               RJDemetra)
`%notin%` <- Negate(`%in%`)


setClassUnion("tbl_null", c("tbl", "NULL"))
setClassUnion('character_null', c('character', 'NULL'))
setClassUnion('date_null', c('Date', 'NULL'))

unregister_dopar <- function() {
  env <- foreach:::.foreachGlobals
  rm(list = ls(name = env), pos = env)
}



NR <- setClass(
  "NR",
  
  ##########################
  ### D?finir les champs ###
  ##########################
  
  slots = c(
    endogenous = "tbl_null",
    exogenous = "tbl_null",
    endo_name = "character",
    exog_name = "character_null",
    ER = "tbl_null",
    ER_name = "character_null",
    # outlier_treatment = "logical", outlier_first = "date_null",
    # outlier_last  = "date_null",
    flow = "character",
    reg_exped = "numeric"
  ),
  
  ##########################
  ### Valeurs par d?faut ###
  ##########################
  
  prototype = list(
    exogenous = NULL,
    endo_name = "vart",
    exog_name = NULL,
    # outlier_treatment = FALSE,
    flow = "I",
    reg_exped = 0
  ),
  
  ################################
  ### V?rification des entr?es ###
  ################################
  
  validity = function(object) {
    # V?rification de nom des colonnes
    if ((object@endo_name) %notin% names(object@endogenous)) {
      return("Le nom d'endog?ne n'est pas trouv? dans le tableau d'endog?ne.")
    }
    
    if (!is.null(object@exogenous)) {
      if (is.null(object@exog_name)) {
        return("Le nom d'exog?ne est demand?.")
      } else{
        if (object@exog_name %notin% names(object@exogenous)) {
          return("Le nom d'exog?ne n'est pas trouv? dans le tableau d'exog?ne.")
        }
      }
    }
    
    if (!is.null(object@ER)) {
      if (is.null(object@ER_name)) {
        return("Le nom de ER est demand?.")
      } else{
        if (object@ER_name %notin% names(object@ER)) {
          return("Le nom de ER n'est pas trouv? dans le tableau ER.")
        }
      }
    }
    
    
    # V?rification du flux
    if ((object@flow != 'I')
        & (object@flow != 'E')) {
      return(
        "Le param?tre 'flow' prend seulement deux options : 'I' pour introduction et 'E' pour exp?dition."
      )
    }
    
    # V?rification de r?gime pour l'introduction
    if ((object@flow == "I") & (object@reg_exped != 0)) {
      stop("Pour les introductions, le r?gime doit ?tre '0'.")
    }
    
    # V?rification de r?gime pour l'exp?dition
    if (object@flow == "E") {
      if (is.na(object@reg_exped)) {
        return("Le r?gime d'exp?dition est manquant.")
      } else{
        if ((object@reg_exped == 21) & (is.null(object@ER))) {
          return("L'?tat r?capitulatif est manquant pour le r?gime 21.")
        }
      }
    }
    
    # Test des valeurs extr?mes
    # if ((object@outlier_treatment == TRUE)
    #     & (is.null(object@outlier_first))
    #     & (is.null(object@outlier_last))){
    #   return("Le traitment des valeurs extr?mes n?cessite la sp?cification du param?tre 'outlier_list' ou du couple 'outlier_first','outlier_last'.")
    # }
    
  }
)



######################################
### Prendre la valeur de l'exog?ne ###
######################################

### Imputer la valeur de l'exog?ne comme valeur estim?e : prendre CA3
### pour les introductions ; ER pour le r?gime 21 de l'exp?dition.
### Utilisation dans l'introduction pour les nouvelles entreprises
### (cr??e en moins d'un an) et l'exog?ne CA3 existe.

setGeneric(
  name = "taking_exog",
  def = function(object, prediction_period, siren) {
    standardGeneric("taking_exog")
  }
)
setMethod(
  f = "taking_exog",
  signature = "NR",
  definition = function(object, prediction_period, siren) {
    data <- (object@exogenous[object@exogenous$siren %in% siren, ]
             %>% left_join(object@endogenous[object@endogenous$siren %in% siren, ],
                           by = c('siren', 'period')))
    prediction <- data.frame(
      siren = rep(siren, each = length(prediction_period)),
      period = rep(prediction_period, length(siren))
    ) %>% mutate_at('period', as.Date)
    prediction <- (
      prediction %>% left_join(data[, c('siren', 'period', object@exog_name)],
                               by = c('siren', 'period'),)
      %>% rename('prediction' = object@exog_name)
      %>% mutate(method = "taking_exog")
    )
    # names(prediction) <- c('siren', 'period', 'prediction')
    return(as_tibble(prediction))
  }
)



#################################################
### Prendre la valeur de l'?tat r?capitulatif ###
#################################################

### Imputer la valeur de l'ER comme valeur estim?e
### pour le r?gime 21 de l'exp?dition.

setGeneric(
  name = "taking_ER",
  def = function(object, prediction_period, siren) {
    standardGeneric("taking_ER")
  }
)
setMethod(
  f = "taking_ER",
  signature = "NR",
  definition = function(object, prediction_period, siren) {
    data <- (object@ER[object@ER$siren %in% siren, ]
             %>% left_join(object@endogenous[object@endogenous$siren %in% siren, ],
                           by = c('siren', 'period')))
    prediction <- data.frame(
      siren = rep(siren, each = length(prediction_period)),
      period = rep(prediction_period, length(siren))
    ) %>% mutate_at('period', as.Date)
    prediction <- (
      prediction %>% left_join(data[, c('siren', 'period', object@ER_name)],
                               by = c('siren', 'period'),)
      %>% rename('prediction' = object@ER_name)
      %>% mutate(method = "taking_ER")
    )
    return(as_tibble(prediction))
  }
)


#####################################
### Prendre la moyenne historique ###
#####################################

### Imputer la moyenne historique pour les nouvelles entreprises
### (cr??es en moins d'un an) et qui n'ont pas de CA3.

cummean.na <- function(x, na.rm = T)
{
  # x = c(NA, seq(1, 10, 1)); na.rm = T
  n <- length(x)
  op <- rep(NA, n)
  for (i in 1:n) {
    op[i] <- ifelse(is.na(x[i]), NA, mean(x[1:i], na.rm = !!na.rm))
  }
  rm(x, na.rm, n, i)
  return(op)
}

setGeneric(
  name = "taking_mean",
  def = function(object, prediction_period, siren) {
    standardGeneric("taking_mean")
  }
)
setMethod(
  f = "taking_mean",
  signature = "NR",
  definition = function(object, prediction_period, siren) {
    prediction <- (
      full_join(
        data.frame(
          siren = rep(siren, each = length(prediction_period)),
          period = as.Date(rep(prediction_period, length(siren))),
          method = rep("taking_mean", length(siren))
        ),
        object@endogenous[object@endogenous$siren %in% siren, ],
        by = c('siren', 'period')
      ) %>%
        group_by(siren) %>%
        arrange(period) %>%
        mutate(prediction = lag(cummean.na(UQ(
          sym(object@endo_name)
        ))),
        method = "taking_mean") %>%
        subset(period %in% prediction_period)
    )
    
    return(as_tibble(prediction[, c('siren', 'period', 'prediction', 'method')]))
  }
)


#################################
### Prendre la valeur de M-12 ###
#################################

### Imputer la valeur de l'ann?e pr?c?dente dans le cas o?
### l'entreprise a moins de 5 ans historique et l'exog?ne n'existe pas

setGeneric(
  name = "taking_last_year",
  def = function(object,
                 prediction_period,
                 siren,
                 alternative = TRUE) {
    standardGeneric("taking_last_year")
  }
)
setMethod(
  f = "taking_last_year",
  signature = "NR",
  definition = function(object,
                        prediction_period,
                        siren,
                        alternative = TRUE) {
    prediction <-
      (
        data.frame(
          siren = rep(siren, each = length(prediction_period)),
          period = as.Date(rep(prediction_period, length(siren)))
        )
        %>% mutate(last_year = ymd(period) - years(1),
                   method = "taking_last_year")
        %>% left_join(
          object@endogenous,
          by = c('siren' = 'siren',
                 'last_year' = 'period')
        )
        %>% rename(prediction = UQ(sym(object@endo_name)))
      )
    if (alternative) {
      new_prediction <- taking_mean(
        object = object,
        prediction_period = prediction_period,
        siren = unique(prediction[is.na(prediction$prediction), ]$siren)
      )
      if (nrow(new_prediction) > 0) {
        prediction <- bind_rows(
          x = inner_join(prediction[c('siren', 'period')], new_prediction, by = c('siren', 'period')),
          y = anti_join(prediction, new_prediction[c('siren', 'period')], by =
                          c('siren', 'period'))
        )
      }
    }
    return(as_tibble(prediction[, c('siren', 'period', 'prediction', 'method')]))
  }
)


###############################
### Lancer un mod?le SARIMA ###
###############################

### A utiliser pour :
### 1) Introduction : les estimations du mois de r?f?rence M
### 2) Introduction : Mois M-1, M-2 et M-3, pour les entreprises
###                   qui ont une historique de plus de cinq ans,
###                   mais n'ont pas de CA3
### 3) Exp?dition

setGeneric(
  name = "launch_sarima",
  def = function(object,
                 prediction_period,
                 learning_first,
                 siren,
                 nbproc = 10,
                 alternative = TRUE) {
    standardGeneric("launch_sarima")
  }
)
setMethod(
  f = "launch_sarima",
  signature = "NR",
  definition = function(object,
                        prediction_period,
                        learning_first,
                        siren,
                        nbproc = 10,
                        alternative = TRUE) {
    pred_period <- as.Date(prediction_period)
    cl <- makeCluster(nbproc)
    registerDoParallel(cl)
    start_time <- Sys.time()
    prediction <- foreach(
      siren = siren,
      .combine = rbind,
      .packages = c('dplyr', 'tsbox',
                    'RJDemetra', 'lubridate')
    ) %dopar% {
      data <- (
        data.frame(
          period = seq.Date(
            from = learning_first,
            to = ymd(first(pred_period)) - months(1),
            by = "month"
          )
        )
        %>% mutate(siren = siren)
        %>% left_join(object@endogenous,
                      by = c('siren', 'period'))
      )
      data_ts <- ts_ts(data[, c('period', object@endo_name)])
      spec_sarima <- regarima_spec_x13(spec = 'RG3',
                                       preliminary.check = TRUE)
      model <- try(regarima(series = data_ts,
                            spec = spec_sarima),
                   silent = TRUE)
      if (!inherits(model, 'try-error')) {
        if (!is.null(model$forecast)) {
          pred <- (
            model$forecast[, 'fcst']
            %>% ts_df()
            %>% rename(period = time, prediction = value)
            %>% left_join(data.frame(
              siren = rep(siren, length(pred_period)),
              period = pred_period
            ), .,
            by = 'period')
          )
        } else{
          pred <- data.frame(
            siren = rep(siren, length(pred_period)),
            period = pred_period,
            prediction = NA
          )
        }
      } else{
        pred <- data.frame(
          siren = rep(siren, length(pred_period)),
          period = pred_period,
          prediction = NA
        )
      }
      return(pred)
    }
    stopCluster(cl)
    time_delta <- Sys.time() - start_time
    prediction <-
      mutate(prediction, method = "launch_sarima")
    if (alternative) {
      new_prediction <- taking_last_year(
        object = object,
        prediction_period = prediction_period,
        siren = unique(prediction[is.na(prediction$prediction)
                                  |
                                    prediction$prediction <= 0, ]$siren),
        alternative = alternative
      )
      if (nrow(new_prediction) > 0) {
        prediction <- bind_rows(
          x = inner_join(prediction[c('siren', 'period')], new_prediction, by = c('siren', 'period')),
          y = anti_join(prediction, new_prediction[c('siren', 'period')], by =
                          c('siren', 'period'))
        )
      }
    }
    return(as_tibble(prediction[, c('siren', 'period', 'prediction', 'method')]))
  }
)


###################################################
### Construire un mod?le de r?gression lin?aire ###
###################################################

setGeneric(
  name = "create_ts",
  def = function(object,
                 data,
                 months = c('july', 'august1',
                            'august2', 'september')) {
    standardGeneric("create_ts")
  }
)
setMethod(
  f = "create_ts",
  signature = "NR",
  definition = function(object,
                        data,
                        months = c('july', 'august1',
                                   'august2', 'september')) {
    ttmp <- cbind(ts_ts(data[, c('period', object@endo_name)]),
                  ts_ts(data[, c('period', object@exog_name)]))
    for (month in months) {
      ttmp <- cbind(ttmp, ts_ts(data[, c('period', month)]))
    }
    colnames(ttmp) <-
      append(c(object@endo_name, object@exog_name), months)
    ttmp[is.na(ttmp)] <- 0
    return(ttmp)
  }
)


setGeneric(
  name = "launch_reglin",
  def = function(object,
                 prediction_period,
                 siren,
                 nb_learning_year = 5,
                 nbproc = 10,
                 alternative = TRUE) {
    standardGeneric("launch_reglin")
  }
)
setMethod(
  f = "launch_reglin",
  signature = "NR",
  definition = function(object,
                        prediction_period,
                        siren,
                        nb_learning_year = 5,
                        nbproc = 10,
                        alternative = TRUE) {
    pred_period <- seq(
      from = min(prediction_period),
      to = max(max(prediction_period), min(prediction_period) + months(12)),
      by = 'month'
    )
    cl <- makeCluster(nbproc)
    registerDoParallel(cl)
    start_time <- Sys.time()
    prediction <- foreach(
      siren = siren,
      .combine = rbind,
      .export = 'create_ts',
      .packages = c('dplyr', 'lubridate', 'tsbox')
    ) %dopar% {
      data <- (
        object@endogenous
        %>% left_join(object@exogenous,
                      by = c('siren', 'period'))
        %>% .[.$siren == siren
              & .$period <= max(pred_period)
              &
                .$period >= (ymd(min(pred_period)) - years(nb_learning_year)), ]
        %>% full_join(data.frame(period = pred_period),
                      by = 'period')
        %>% mutate(
          year = year(period),
          july = case_when(((
            month(period) == 7
          )
          & ((UQ(sym(
            object@exog_name
          )) == 0
          |
            is.na(UQ(
              sym(object@exog_name)
            )))
          )) ~ 1,
          TRUE ~ 0),
          august1 = case_when(((
            month(period) == 8
          )
          &
            ((UQ(sym(
              object@exog_name
            ))[month(period) == 7] == 0)
            |
              is.na(UQ(sym(
                object@exog_name
              ))[month(period) == 7])
            )) ~ 1,
          TRUE ~ 0),
          august2 = case_when(((
            month(period) == 8
          )
          & ((UQ(sym(
            object@exog_name
          )) == 0) |
            is.na(UQ(sym(
              object@exog_name
            )))
          )) ~ 1,
          TRUE ~ 0),
          september = case_when(((
            month(period) == 9
          )
          &
            ((UQ(sym(
              object@exog_name
            ))[month(period) == 8] == 0)
            |
              is.na(UQ(sym(
                object@exog_name
              ))[month(period) == 8])
            )) ~ 1,
          TRUE ~ 0)
        )
      )
      
      print(data)
      data <- create_ts(object, data)
      model <- try(lm(as.formula(paste(
        object@endo_name,
        paste(
          c(
            object@exog_name,
            'july',
            'august1',
            'august2',
            'september'
          ),
          collapse = '+'
        ),
        sep = '~'
      )),
      data = window(data, end = c(
        year(min(pred_period) - months(1)),
        month(min(pred_period) -
                months(1))
      ))),
      silent = TRUE)
      if (!inherits(model, 'try-error')) {
        model <- try(step(model, direction = 'backward'),
                     silent = TRUE)
        if (!inherits(model, 'try-error')) {
          pred <- data.frame(
            siren = rep(siren, length(pred_period)),
            period = pred_period,
            prediction = predict(model, newdata = window(data, start = c(
              year(min(pred_period)),
              month(min(pred_period))
            )))
          )
        } else{
          pred <- data.frame(
            siren = rep(siren, length(pred_period)),
            period = pred_period,
            prediction = NA
          )
        }
      } else{
        pred <- data.frame(
          siren = rep(siren, length(pred_period)),
          period = pred_period,
          prediction = NA
        )
      }
    }
    # unregister_dopar()
    stopCluster(cl)
    time_delta <- Sys.time() - start_time
    prediction <-
      mutate(prediction, method = "launch_reglin")
    # print(sprintf("Temps d'ex?cution est %f %s", time_delta, units(time_delta)))
    if (alternative) {
      new_prediction <- taking_last_year(
        object = object,
        prediction_period = prediction_period,
        siren = unique(prediction[is.na(prediction$prediction)
                                  |
                                    prediction$prediction <= 0, ]$siren),
        alternative = TRUE
      )
      prediction <- bind_rows(
        x = inner_join(prediction[c('siren', 'period')], new_prediction, by = c('siren', 'period')),
        y = anti_join(prediction, new_prediction[c('siren', 'period')], by =
                        c('siren', 'period'))
      )
    }
    return(as_tibble(prediction[prediction$period %in% prediction_period,
                                c('siren', 'period', 'prediction', 'method')]))
  }
)


################################
### Automatiser l'estimation ###
################################

setGeneric(
  name = "estimNR",
  def = function(object,
                 prediction_period,
                 siren,
                 ref_period,
                 learning_first,
                 nb_learning_year = 5,
                 nbproc = 10,
                 alternative = TRUE,
                 na_imput = TRUE,
                 negative_imput = TRUE,
                 get_method_ref = FALSE) {
    standardGeneric("estimNR")
  }
)
setMethod(
  f = "estimNR",
  signature = "NR",
  definition = function(object,
                        prediction_period,
                        siren,
                        ref_period,
                        learning_first,
                        nb_learning_year = 5,
                        nbproc = 10,
                        alternative = TRUE,
                        na_imput = TRUE,
                        negative_imput = TRUE,
                        get_method_ref = FALSE) {
    if (object@flow == 'E' & object@reg_exped == 29) {
      group_siren <-
        (
          object@endogenous[object@endogenous$siren %in% siren, ]
          %>% group_by(siren)
          %>% summarise(nobs = sum((
            period < (ymd(min(
              prediction_period
            )) - years(1))
          )
          &
            (UQ(
              sym(object@endo_name)
            ) > 0)))
          %>% mutate(method_ref = case_when(
            (nobs >= 12 * nb_learning_year) ~ 'launch_sarima',
            TRUE ~ 'taking_last_year'
          ))
        )
      prediction <- data.frame()
      for (method_ref in unique(group_siren$method_ref)) {
        siren_list <-
          group_siren[group_siren$method_ref == method_ref, ]$siren
        if (method_ref == "taking_last_year") {
          pred <-
            do.call(get(method_ref),
                    args = list(object, prediction_period, siren_list, alternative))
          
        } else{
          pred <-
            do.call(
              get(method_ref),
              args = list(
                object,
                prediction_period,
                learning_first,
                siren_list,
                nbproc,
                alternative
              )
            )
        }
        prediction <- rbind(prediction, pred)
      }
    } else{
      if ((ref_period == prediction_period) |
          (object@flow == "E" & object@reg_exped == 21)) {
        # print(object@endogenous[object@endogenous$siren %in% siren,])
        group_siren <-
          (
            object@endogenous[object@endogenous$siren %in% siren, ]
            %>% group_by(siren)
            %>% summarise(nobs = sum((
              period < (ymd(min(
                prediction_period
              )) - years(1))
            )
            &
              (UQ(
                sym(object@endo_name)
              ) > 0)))
            %>% mutate(
              method_ref = case_when(
                (nobs >= 12 * nb_learning_year) ~ 'launch_sarima',
                TRUE ~ 'taking_last_year'
              )
            )
          )
        
        if (object@flow == "E" & object@reg_exped == 21) {
          group_siren[group_siren$siren %in%
                        object@ER[object@ER$period %in%
                                    prediction_period, ]$siren, ]$method_ref <-
            "taking_ER"
        }
      } else{
        group_siren <-
          (
            left_join(
              object@endogenous[object@endogenous$siren %in% siren, ],
              object@exogenous[object@exogenous$siren %in% siren, ],
              by = c('siren', 'period')
            )
            %>% group_by(siren) %>% summarise(notna_exog = sum((
              is.na(UQ(sym(
                object@exog_name
              ))) == FALSE
            )),
            nobs = sum(period < (
              ymd(min(prediction_period)) - years(1)
            )))
            %>% mutate(
              method_ref = case_when(
                ((nobs == 0) & (notna_exog > 0)) ~ 'taking_exog',
                ((nobs == 0) &
                   (notna_exog == 0)) ~ 'taking_mean',
                ((nobs < 12 * nb_learning_year) &
                   (notna_exog == 0)) ~ 'taking_last_year',
                ((nobs >= 12 * nb_learning_year) &
                   (notna_exog == 0)) ~ 'launch_sarima',
                TRUE ~ 'launch_reglin'
              )
            )
          )
      }
      
      prediction <- data.frame()
      
      for (method_ref in unique(group_siren$method_ref)) {
        siren_list <-
          group_siren[group_siren$method_ref == method_ref, ]$siren
        
        if (method_ref %in% c('taking_exog', 'taking_mean', 'taking_ER')) {
          pred <-
            do.call(get(method_ref),
                    args = list(object, prediction_period, siren_list))
        } else{
          if (method_ref == 'taking_last_year') {
            pred <-
              do.call(
                get(method_ref),
                args = list(object, prediction_period, siren_list, alternative)
              )
          } else{
            if (method_ref == 'launch_sarima') {
              pred <-
                do.call(
                  get(method_ref),
                  args = list(
                    object,
                    prediction_period,
                    learning_first,
                    siren_list,
                    nbproc,
                    alternative
                  )
                )
            } else{
              pred <-
                do.call(
                  get(method_ref),
                  args = list(
                    object,
                    prediction_period,
                    siren_list,
                    nb_learning_year,
                    nbproc,
                    alternative
                  )
                )
            }
          }
        }
        prediction <- rbind(prediction, pred)
      }
    }
    # }
    if (na_imput) {
      prediction[is.na(prediction$prediction), ]$prediction <- 0
    }
    if (negative_imput) {
      prediction[prediction$prediction < 0, ]$prediction <- 0
    }
    if (get_method_ref) {
      return(left_join(prediction, group_siren[, c('siren', 'method_ref')],
                       by = c('siren')))
    } else{
      return(prediction)
    }
  }
)

get_NR_list <- function(sample, endogenous, date) {
  date_beg <- sort(unique(sample$date_beg))
  date_sample <- date_beg[findInterval(date, date_beg)]
  sample <- subset(sample,
                   subset = (date_beg == date_sample),
                   select = siren) %>%
    unique()
  endo <- subset(endogenous,
                 subset = (period == date),
                 select = -period) %>%
    column_to_rownames(var = "siren") %>%
    mutate(V = rowSums(., na.rm = T)) %>%
    subset(subset = (V > 0)) %>%
    rownames_to_column(var = "siren")
  NR_list <- anti_join(sample,
                       endo,
                       by = 'siren') %>%
    mutate(period = date)
  return(NR_list)
}

get_flow_name <- function(object) {
  flow_dict <- data.frame(
    flow = c('E', 'E', 'I'),
    regdem = c(21, 29, 0),
    flow_name = c('exped_21', 'exped_29', 'intro')
  )
  return(flow_dict[flow_dict$flow == object@flow &
                     flow_dict$regdem == object@reg_exped, ]$flow_name)
}

get_flow_name_register <- function(object) {
  flow_dict <- data.frame(flow = c('E', 'I'),
                          flow_name = c('exped', 'intro'))
  return(flow_dict[flow_dict$flow == object@flow, ]$flow_name)
}

setGeneric(
  name = "launch_estimation",
  def = function(object,
                 date,
                 sample,
                 input,
                 learning_from,
                 nb_years_regressions,
                 nbproc = 5) {
    standardGeneric("launch_estimation")
  }
)
setMethod(
  f = "launch_estimation",
  signature = "NR",
  definition = function(object,
                        date,
                        sample,
                        input,
                        learning_from,
                        nb_years_regressions,
                        nbproc = 5) {
    flow_name <- get_flow_name(object)
    siren_imput <- (get_NR_list(sample,
                                endogenous = object@endogenous,
                                date = date))$siren
    
    print(sprintf("Flow %s, Date %s", flow_name,
                  format(as_date(date), "%Y-%m")))
    print(length(siren_imput))
    
    date_ref <- as_date(input@date_ref)
    imput_data <- estimNR(
      object = object,
      prediction_period = as_date(date),
      ref_period = date_ref,
      siren = siren_imput,
      learning_first = learning_from,
      get_method_ref = T,
      nbproc = nbproc,
      nb_learning_year = nb_years_regressions
    )
    saveRDS(imput_data,
            file.path(
              input@output_directory,
              sprintf(
                "estim_%s_%s_ref%s.rds",
                flow_name,
                format(as_date(date), "%Y%m"),
                format(date_ref, "%Y%m")
              )
            ))
    return(imput_data)
  }
)

setGeneric(
  name = "launch_all_estimations",
  def = function(object,
                 dates,
                 sample,
                 input,
                 learning_from,
                 nb_years_regressions = 5,
                 nbproc = 5) {
    standardGeneric("launch_all_estimations")
  }
)
setMethod(
  f = "launch_all_estimations",
  signature = "NR",
  definition = function(object,
                        dates,
                        sample,
                        input,
                        learning_from,
                        nb_years_regressions = 5,
                        nbproc = 5) {
    flow_name <- get_flow_name(object)
    filename <- file.path(input@output_directory,
                          sprintf("%s_imput.rds", flow_name))
    if (file.exists(filename)) {
      imput_data <- readRDS(filename)
    } else{
      imput_data <- dates %>%
        map_df(
          ~ launch_estimation(
            object = object,
            date = .x,
            sample = sample,
            input = input,
            learning_from = learning_from,
            nb_years_regressions = nb_years_regressions,
            nbproc = nbproc
          )
        ) %>%
        bind_rows()
      saveRDS(imput_data,
              filename)
    }
    return(imput_data)
  }
)


####################
### Distribution ###
####################

setGeneric(
  name = "distribution",
  def = function(object,
                 estim_result,
                 data_distribution,
                 sirens = "all",
                 ventil_imput = 'all',
                 ventil_output = NULL,
                 nbproc = 10,
                 lag_width = 1) {
    standardGeneric("distribution")
  }
)
setMethod(
  f = "distribution",
  signature = "NR",
  definition = function(object,
                        estim_result,
                        data_distribution,
                        sirens = "all",
                        ventil_imput = 'all',
                        ventil_output = NULL,
                        nbproc = 10,
                        lag_width = 1) {
    if ((ventil_imput != 'all') &
        (class(ventil_imput) == 'character')) {
      stop("ventil_imput doit ?tre 'all' ou une liste de caract?res.")
    } else{
      if (ventil_imput == 'all') {
        group <- names(data_distribution)
        group <- group[which(group != object@endo_name)]
      } else{
        group <- append(c('siren', 'period'), ventil_imput)
      }
    }
    if (sirens == "all") {
      selected_sirens <- unique(estim_result$siren)
    } else{
      selected_sirens <- copy(sirens)
    }
    # if ((object@flow == "E") & ("regdem" %in% group)){
    #   stop("La ventilation par r?gime ne peut pas ?tre prise en compte en exp?dition.")
    # }
    # print(group)
    # period = unique(estim_result$period)
    distribution <-
      (data_distribution[data_distribution$siren %in% selected_sirens, ]
       %>% group_by_at(.vars = group)
       %>% summarise(endo = sum(UQ(
         sym(object@endo_name)
       ),
       na.rm = TRUE)))
    # print(names(distribution))
    distribution <- (
      distribution
      %>% group_by_at(.vars = c('siren', 'period'))
      %>% mutate(sum_endo = sum(endo, na.rm = TRUE))
      %>% ungroup()
      %>% mutate(ratio = endo / sum_endo)
    )
    dist <- (
      distribution
      %>% group_by(siren)
      %>% summarise(period = unique(period))
      %>% rbind(estim_result[, c('siren', 'period')])
      %>% arrange(siren, period)
      %>% group_by(siren)
      %>% mutate(
        period_last = zoo::rollapply(
          data.table::shift(period, 1, fill = NA, type = 'lag'),
          width = 1,
          FUN = copy,
          align = 'right',
          fill = NA
        )
      )
      %>% ungroup()
    )
    dist_prediction <-
      (left_join(estim_result[estim_result$siren %in% selected_sirens,],
                 dist,
                 by = c('siren', 'period')))
    dist_prediction <- (
      dist_prediction
      %>% left_join(
        distribution,
        by = c('siren', 'period_last' = 'period'),
        suffix = c('_imput', '_ventil')
      )
      %>% mutate(dist_prediction = prediction *
                   ratio)
    )
    if (is.null(ventil_output)) {
      return(dist_prediction)
    } else{
      return(dist_prediction
             %>% group_by_(.dots = c('period', ventil_output))
             %>% summarise(dist_prediction = sum(dist_prediction, na.rm = TRUE)))
    }
  }
)

setGeneric(
  name = "launch_distribution",
  def = function(object,
                 input,
                 imput_result,
                 date,
                 detail_data) {
    standardGeneric("launch_distribution")
  }
)
setMethod(
  f = "launch_distribution",
  signature = "NR",
  definition = function(object,
                        input,
                        imput_result,
                        date,
                        detail_data) {
    result <- filter(.data = imput_result, period == as_date(date))
    distribution_result <- distribution(
      object = object,
      estim_result = result,
      data_distribution = detail_data[, c(
        'siren',
        'period',
        'a129',
        'nc8',
        'pyod',
        'payp',
        'dept',
        'temo',
        'natr',
        'regdem',
        'conf',
        object@endo_name
      )],
      sirens = unique(result$siren)
    )
    return(distribution_result)
  }
)

setGeneric(
  name = "launch_all_distributions",
  def = function(object,
                 input,
                 imput_result,
                 dates,
                 detail_data) {
    standardGeneric("launch_all_distributions")
  }
)
setMethod(
  f = "launch_all_distributions",
  signature = "NR",
  definition = function(object,
                        input,
                        imput_result,
                        dates,
                        detail_data) {
    flow_name <- get_flow_name_register(object)
    filename <- file.path(input@output_directory,
                          sprintf("%s_ventil.rds", flow_name))
    if (file.exists(filename)) {
      distribution_data <- readRDS(filename)
    } else{
      distribution_data <- dates %>%
        map_df(
          ~ launch_distribution(
            object = object,
            input = input,
            imput_result = imput_result,
            date = .x,
            detail_data = detail_data
          )
        ) %>%
        bind_rows()
      saveRDS(distribution_data,
              filename)
    }
    return(distribution_data)
  }
)

##################################
### Add historical simulations ###
##################################

setGeneric(
  name = "add_historical_simulation",
  def = function(object, input, current_result, type = 'ventil') {
    standardGeneric("add_historical_simulation")
  }
)
setMethod(
  f = "add_historical_simulation",
  signature = "NR",
  definition = function(object, input, current_result, type = "ventil") {
    if (type %notin% c('ventil', 'imput')) {
      stop("'type' must be 'ventil' or 'imput'.")
    }
    flow_name <- get_flow_name_register(object)
    filename <- file.path(input@output_directory,
                          sprintf("%s_%s_with_past_month.rds",
                                  flow_name, type))
    if (file.exists(filename)) {
      result <- readRDS(filename)
    } else{
      past_month <-
        setdiff(input@date_publication, input@date_prediction) %>%
        as_date()
      
      past_simulation <-
        import_historical_simulation(object = input,
                                     flow = object@flow,
                                     date = past_month)
      
      past_NR <- past_month %>%
        map_df(
          ~ get_NR_list(
            sample = get_sample_by_flow(
              sample = import_sample(
                input_directory = input@input_directory,
                sample = input@sample
              ),
              flow = object@flow
            ),
            endogenous = object@endogenous,
            date = .x
          )
        ) %>%
        bind_rows()
      past_simulation <-
        semi_join(past_simulation, past_NR, by = c('siren', 'period'))
      if (type == "ventil") {
        result <-
          bind_rows(arrange(past_simulation, period), current_result)
      } else{
        result <- bind_rows(
          past_simulation %>%
            group_by(siren, period) %>%
            summarise(
              method = unique(method),
              method_ref = unique(method_ref),
              prediction = sum(unique(prediction))
            ),
          current_result
        )
        saveRDS(result, filename)
      }
      return(result)
    }
  }
)


###################
### Add gazelec ###
###################

setGeneric(
  name = "add_gazelec",
  def = function(object,
                 input,
                 result,
                 type,
                 by_regdem = F,
                 siren_list = c('095580841', '440117620', '444619258'),
                 pass_names) {
    standardGeneric("add_gazelec")
  }
)
setMethod(
  f = "add_gazelec",
  signature = "NR",
  definition = function(object,
                        input,
                        result,
                        type,
                        by_regdem = F,
                        siren_list = c('095580841', '440117620', '444619258'),
                        pass_names) {
    gazelec_data <-
      import_gazelec(input, object@flow, pass_names = pass_names)
    flow_name <- get_flow_name_register(object)
    if (by_regdem) {
      filename <- file.path(
        input@output_directory,
        sprintf(
          "%s_%d_%s_with_gazelec.rds",
          flow_name,
          object@reg_exped,
          type
        )
      )
    } else{
      filename <- file.path(input@output_directory,
                            sprintf("%s_%s_with_gazelec.rds",
                                    flow_name, type))
    }
    
    if (file.exists(filename)) {
      result <- readRDS(filename)
    } else{
      if (type == "imput") {
        if (!input@add_gazelec_data) {
          result <- subset(result,
                           subset = (siren %notin% siren_list))
        } else if (input@use_gazelec_file) {
          result <- bind_rows(
            result %>%
              subset(subset = (siren %notin% siren_list)),
            gazelec_data %>%
              group_by(siren, period) %>%
              summarise(
                method = unique(method),
                method_ref = unique(method_ref),
                prediction = unique(prediction)
              ) %>%
              ungroup()
          )
        }
      } else if (type == "ventil") {
        if (!input@add_gazelec_data) {
          result <- result %>%
            subset(subset = (siren %notin% siren_list))
        } else if (input@use_gazelec_file) {
          result <- bind_rows(result %>%
                                subset(subset = (siren %notin% siren_list)),
                              gazelec_data)
        }
      } else{
        stop("'type' must be 'imput' or 'ventil'.")
      }
      saveRDS(result,
              filename)
    }
    return(result)
  }
)


##################
### Remove MSD ###
##################

setGeneric(
  name = "remove_msd",
  def = function(object,
                 msd,
                 result,
                 type,
                 by_regdem = F,
                 input) {
    standardGeneric("remove_msd")
  }
)
setMethod(
  f = "remove_msd",
  signature = "NR",
  definition = function(object,
                        msd,
                        result,
                        type,
                        by_regdem = F,
                        input) {
    if (type %notin% c('imput', 'ventil')) {
      stop("'type' must be 'imput' or 'ventil'.")
    }
    flow_name <- get_flow_name_register(object)
    if (by_regdem) {
      filename <- file.path(
        input@output_directory,
        sprintf("%s_%d_%s_rect.rds",
                flow_name, object@reg_exped, type)
      )
    } else{
      filename <- file.path(input@output_directory,
                            sprintf("%s_%s_rect.rds",
                                    flow_name,
                                    type))
    }
    if (file.exists(filename)) {
      rectified_result <- readRDS(filename)
    } else{
      rectified_result <- result %>%
        anti_join(subset(msd,
                         subset = ((
                           flux == object@flow
                         ))), # & (MSD == 1))),
                  by = c('siren', 'period'))
      saveRDS(rectified_result,
              filename)
    }
    return(rectified_result)
  }
)


#####################
### Export result ###
#####################

export_imput_to_csv <- function(data, date, filename_format) {
  write.csv2(
    x = subset(data, subset = (period == as_date(date))),
    file = sprintf(filename_format, format(as_date(date), "%Y%m")),
    row.names = F,
    na = ""
  )
}

export_ventil_to_csv <- function(data, filename) {
  write.csv2(
    x = data,
    file = filename,
    row.names = F,
    na = ""
  )
}

export_to_historical_basis <-
  function(input, data, flow, save = T) {
    exo <-
      ifelse(
        test = grepl(pattern = "_PC", x = input@output_directory),
        yes = "prechiffre",
        no = "chiffre"
      )
    historical_basis <-
      readRDS(file.path(input@historical_directory,
                        "Base_historique.rds")) %>%
      mutate(
        period_last = as.Date(period_last),
        period = as.Date(period),
        date_maj = as.Date(date_maj)
      ) %>%
      bind_rows(data %>%
                  mutate(
                    flux = flow,
                    mois_ref = format(input@date_ref, "%Y%m"),
                    source = exo,
                    date_maj = Sys.Date()
                  ))
    if (save) {
      saveRDS(
        historical_basis,
        file.path(input@historical_directory, "Base_historique.rds")
      )
    }
    return(historical_basis)
  }


###################
### Get NR list ###
###################

get_NR_list_from_result <- function(result_intro, result_exped) {
  NR_list <- bind_rows(
    result_intro %>%
      group_by(siren, period) %>%
      summarise(count = n()) %>%
      ungroup() %>%
      select(siren, period) %>%
      mutate(flow = "I"),
    result_exped %>%
      group_by(siren, period) %>%
      summarise(count = n()) %>%
      ungroup() %>%
      select(siren, period) %>%
      mutate(flow = "E")
  ) %>%
    mutate(
      mdep = month(period),
      last_period = period - years(1),
      trimestre = sprintf("%d.%d", year(period), quarter(period)),
      last_trimestre = sprintf("%d.%d", year(last_period),
                               quarter(last_period)),
      imex = ifelse(
        test = (flow == "I"),
        yes = 3,
        no = 4
      )
    )
  return(NR_list)
}