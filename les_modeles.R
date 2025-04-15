

# Partie 1 : les series ----------------------------------------------------

# creer les requetes

# voir partie launch_request

ca3 = arrow::open_dataset("../dsece-imputation-nr/CA3 Parquet/") 


ca3_extract = base_CA3 %>% 
  arrow::open_dataset() %>% 
  dplyr::filter(mois_envoi == 202502) %>% 
  select(SIREN, PERIODE, Medoc_0031) %>% 
  collect() %>% 
  clean_names() 


histo = base_historique %>% 
  arrow::open_dataset() %>% 
  dplyr::filter(mois_ref == 202501) %>% 
  collect()



# Partie 2 : les modèles --------------------------------------------------


## La valeur CA3 -------------------------------------------------------

taking_exog = function(data, prediction_period, siren_list) {
  
  prediction <- data.frame(
    siren = rep(siren_list, each = length(prediction_period)),
    period = rep(prediction_period, length(siren_list))) %>%
    mutate_at('period', as.Date)
  
  prediction <- 
    prediction %>% left_join(data,
                             by = c('siren', 'period')) %>%
    rename('prediction' = medoc_0031) %>% 
    mutate(method = "taking_exog")
  
  return(as_tibble(prediction))
}


 # ok
voir = taking_exog(
                  data = exogenous_intro,
                  siren_list = c("838752400","327086245"),
                  prediction_period = c("2024-12-01","2025-01-01"))


## La valeur de l'ER ---------------------------------------------------

taking_ER = function(data, prediction_period, siren_list) {
  
  prediction <- data.frame(
    siren = rep(siren_list, each = length(prediction_period)),
    period = rep(prediction_period, length(siren_list))) %>% 
    mutate_at('period', as.Date)
  
  prediction <- 
    prediction %>% left_join(data,
                             by = c('siren', 'period')) %>%
      rename('prediction' = vfte) %>% 
      mutate(method = "taking_ER")

  return(as_tibble(prediction))
}

# ok
voir_ER = taking_ER(data = ER,
                    siren_list = c("395388077","659803175","951849652"),
                    prediction_period = c("2024-12-01","2025-01-01"))


## Le point projeté par sarima -----------------------------------------


launch_sarima = function(data, siren_list, prediction_period) {
  pacman::p_load(tsbox, RJDemetra)
  
  pred_period <- as.Date(prediction_period)
  
  data <- (
    data.frame(period = seq.Date(
      from = learning_from,
      to = ymd(first(pred_period)) - months(1),
      by = "month"
    )) %>% mutate(siren = siren_list) %>%
      left_join(data, by = c('siren', 'period'))
  )
  
  data_ts <- tsbox::ts_ts(data)
  spec_sarima <- regarima_spec_x13(spec = 'RG3',
                                   preliminary.check = TRUE)
  model <- try(regarima(series = data_ts,
                        spec = spec_sarima),
               silent = TRUE)
  
  if (!inherits(model, 'try-error')) {
    if (!is.null(model$forecast)) {
      
      pred <- model$forecast[, 'fcst'] %>%
        ts_df() %>%
        rename(period = time, prediction = value) %>%
        inner_join(data.frame(siren = rep(siren_list, length(pred_period)),
                              period = pred_period),
                   by = 'period')
    } else{
      pred <- data.frame(
        siren = rep(siren_list, length(pred_period)),
        period = pred_period,
        prediction = NA
      )
    }
  } else{
    pred <- data.frame(
      siren = rep(siren_list, length(pred_period)),
      period = pred_period,
      prediction = NA
    )
  }
  return(pred)
  
}


 c("962227351", "900000000") %>% 
  map_df(
    ~ launch_sarima(
      data = endogenous_intro,
      siren_list = .,
      prediction_period = "2025-01-01"
    )
  ) 


 c("962227351", "900000000") %>% 
  map_df(
  ~ launch_sarima(
    data = endogenous_exped %>% select(siren,period,vart=vart_29),
    siren_list = .,
    prediction_period = "2025-01-01"
  )
) 

## La valeur du même mois l'année précédente -----------------------------------

# taking_last_year

  taking_last_year = function(data,
                        prediction_period,
                        siren_list) {
    prediction <-
      data.frame(
        siren = rep(siren_list, each = length(prediction_period)),
        period = as.Date(rep(prediction_period, length(siren_list)))) %>% 
      mutate(last_year = ymd(period) - years(1),
             method = "taking_last_year") %>% 
      left_join(
        data,
        by = c('siren' = 'siren',
               'last_year' = 'period')) %>% rename(prediction = vart)
    
  return(prediction)
  }

 taking_last_year(data = endogenous_intro,
                  prediction_period = "2025-01-01",
                  siren_list = "962227351")
 
 taking_last_year(
   data = endogenous_exped %>% select(siren, period, vart = vart_29),
   prediction_period = "2025-01-01",
   siren_list = "962227351"
 ) 

## La valeur moyenne -----------------------------------------------------------

# taking_mean

taking_mean = function(data, prediction_period, siren_list) {
    
  prediction <- 
    data.frame(
      siren = rep(siren_list, each = length(prediction_period)),
      period = as.Date(rep(prediction_period, length(siren_list))),
      method = rep("taking_mean", length(siren_list))
    ) %>% 
    full_join(
      data %>% 
        filter(siren %in% siren_list),
      by = c('siren', 'period'))
  
  pred = prediction %>%
    group_by(siren) %>%
    arrange(period) %>%
    mutate(
      cummean_vart = if_else(is.na(vart), NA_real_, cummean(replace_na(vart, NA_real_))),
      prediction = lag(cummean_vart),
      method = "taking_mean") %>%
    filter(period == prediction_period) %>% 
    select(-cummean_vart)
    
    return(pred)
  }


taking_mean(
  data = endogenous_intro,
  prediction_period = "2025-01-01",
  siren_list = c("978394542", "948848791", "987611118")
) 


taking_mean(
  data = endogenous_exped %>% select(siren, period, vart = vart_21),
  prediction_period = "2025-01-01",
  siren_list = c("978394542", "948848791", "987611118")
) 

## Le point calculé par regression linéaire -----------------------------------------------------------

# launch_reglin


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



create_ts <- function(data, endo_name, exog_name, months = c("july", "august1", "august2", "september")) {
  vars <- c(endo_name, exog_name, months)
  
  ts_data <- data |>
    select(period, all_of(vars)) |>
    tsbox::ts_ts() |>
    stats::window()
  
  # Remplace les NA par 0
  ts_data[is.na(ts_data)] <- 0
  
  colnames(ts_data) <- vars
  return(ts_data)
}



launch_reglin <- function(endogenous,
                          exogenous,
                          prediction_period,
                          siren_list,
                          endo_name,
                          exog_name,
                          nb_learning_year = 5,
                          nbproc = 10
                          ) {

  pred_period <- seq(
    from = min(prediction_period),
    to = max(max(prediction_period), min(prediction_period) %m+% months(12)),
    by = "month"
  )

  
  prediction <- endogenous_intro |>
                            filter(siren == "910374628") |>
                            left_join(exogenous_intro, by = c("siren", "period")) |>
                            filter(period >= min(pred_period) - years(nb_learning_year),
                                   period <= max(pred_period)) |>
                            full_join(data.frame(period = pred_period), by = "period") |>
                            arrange(period) |>
                            mutate(
                              year = year(period),
                              july = if_else(month(period) == 7 & (is.na(medoc_0031) | medoc_0031 == 0), 1, 0),
                              august1 = if_else(
                                month(period) == 8 &
                                  lag(medoc_0031, order_by = period) == 0,
                                1, 0
                              ),
                              august2 = if_else(month(period) == 8 & (is.na(medoc_0031) | medoc_0031 == 0), 1, 0),
                              september = if_else(
                                month(period) == 9 &
                                  lag(medoc_0031, 1, order_by = period) == 0,
                                1, 0
                              )
                            )
                          
                          ts_data <- create_ts(data, endo_name = endo_name, exog_name = exog_name)
                          
                          # Construction de la formule
                          formula_str <- paste(
                            endo_name,
                            paste(c(exog_name, "july", "august1", "august2", "september"), collapse = " + "),
                            sep = " ~ "
                          )
                          
                          model <- try(
                            lm(as.formula(formula_str),
                               data = stats::window(ts_data, end = c(year(min(pred_period %m-% months(1))), month(min(pred_period %m-% months(1)))))),
                            silent = TRUE
                          )
                          
                          if (!inherits(model, "try-error")) {
                            model <- try(step(model, direction = "backward"), silent = TRUE)
                            if (!inherits(model, "try-error")) {
                              pred <- predict(model, newdata = stats::window(ts_data, start = c(year(min(pred_period)), month(min(pred_period)))))
                              return(tibble(siren = siren, period = pred_period, prediction = pred))
                            }
                          }
                          
                          # En cas d'échec
                          tibble(siren = siren, period = pred_period, prediction = NA_real_)
                        }
  
  stopCluster(cl)
  
  prediction <- prediction |>
    mutate(method = "launch_reglin")
  
  # Plan B si alternative demandée
  if (alternative) {
    alt_prediction <- taking_last_year(
      endogenous = endogenous,
      prediction_period = prediction_period,
      siren = prediction |>
        filter(is.na(prediction) | prediction <= 0) |>
        pull(siren) |>
        unique(),
      alternative = TRUE
    )
    
    prediction <- bind_rows(
      inner_join(prediction |> select(siren, period), alt_prediction, by = c("siren", "period")),
      anti_join(prediction, alt_prediction, by = c("siren", "period"))
    )
  }
  
  prediction |>
    filter(period %in% prediction_period) |>
    select(siren, period, prediction, method)
}
