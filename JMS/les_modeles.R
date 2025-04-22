
library(tidyverse)
## La valeur CA3 -------------------------------------------------------

taking_exog = function(data, exogenous, prediction_period, siren_list) {
  
  prediction <- data.frame(
    siren = rep(siren_list, each = length(prediction_period)),
    period = rep(prediction_period, length(siren_list)) %>% 
      lubridate::as_date()) 
  
  if (!is.null(exogenous)) {
  prediction <- 
    prediction %>% 
    left_join(y = exogenous,
              by = join_by(siren, period)) %>%
    mutate(method = "taking_exog")
  }
  
  if("medoc_0031" %in% colnames(prediction)){
    return(prediction$medoc_0031)
    }
}


## La valeur de l'ER ---------------------------------------------------

taking_ER = function(data, exogenous, prediction_period, siren_list) {
  prediction <- data.frame(
    siren = rep(siren_list, each = length(prediction_period)),
    period = rep(prediction_period, length(siren_list))) %>% 
    mutate_at('period', as.Date)
  
  if (!is.null(exogenous)) {
    prediction <-
      prediction %>%
      left_join(y = exogenous,
                by = c('siren', 'period')) %>%
      mutate(method = "taking_ER")
  }

  if("vfte"%in% colnames(prediction)){
    prediction <-
      prediction %>% 
      rename(prediction = vfte) 
  }
  return(prediction$prediction)
  }


## Le point projeté par sarima -----------------------------------------


launch_sarima = function(data, siren_list, prediction_period) {
  pacman::p_load(tsbox, RJDemetra)
  
  pred_period <- as.Date(prediction_period)
  
  data <- (
    data.frame(period = seq.Date(
      from = learning_from,
      to = ymd(first(pred_period)) - months(1),
      by = "month"
    )) %>% 
      mutate(siren = siren_list) %>%
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
  return(pred$prediction)  
}

launch_sarima_refactor <- function(data, siren_list, prediction_period, learning_from = NULL) {
  requireNamespace("tsbox")
  requireNamespace("RJDemetra")
  requireNamespace("lubridate")
  requireNamespace("dplyr")
  
  pred_period <- lubridate::as_date(prediction_period)
  if (is.null(learning_from)) {
    learning_from <- min(data$period, na.rm = TRUE)
  }
  end_date <- pred_period[1] - lubridate::period(months = 1L)
  
  base <- expand.grid(
    siren = siren_list,
    period = seq.Date(
      from = lubridate::as_date(learning_from),
      to = end_date,
      by = "month"
    ),
    stringsAsFactors = FALSE
  )
  
  merged <- dplyr::left_join(base, data, by = c("siren", "period"))
  data_ts <- tsbox::ts_ts(merged)
  
  spec <- RJDemetra::regarima_spec_x13(spec = "RG3", preliminary.check = TRUE)
  model <- try(RJDemetra::regarima(series = data_ts, spec = spec), silent = TRUE)
  
  if (!inherits(model, "try-error") && !is.null(model$forecast)) {
    fc_df <- tsbox::ts_df(model$forecast[, "fcst"])
    colnames(fc_df) <- c("period", "prediction")
    out <- dplyr::tibble(
      siren = rep(siren_list, length(pred_period)),
      period = pred_period
    ) %>%
      dplyr::left_join(fc_df, by = "period")
  } else {
    out <- dplyr::tibble(
      siren = rep(siren_list, length(pred_period)),
      period = pred_period,
      prediction = NA_real_
    )
  }
  
  out$prediction
}

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
               'last_year' = 'period')) %>% 
      rename(prediction = vart)
    
    return(prediction$prediction)
    }


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
  
  pred =
    prediction %>%
    group_by(siren) %>%
    arrange(period) %>%
    mutate(
      cummean_vart = if_else(is.na(vart), NA_real_, cummean(replace_na(vart, NA_real_))),
      prediction = lag(cummean_vart),
      method = "taking_mean"
    ) %>%
    ungroup() %>% 
    filter(period == prediction_period) %>%
    select(-cummean_vart)
    
  return(pred$prediction)
  }

## Le point calculé par regression linéaire -----------------------------------------------------------

# launch_reglin

create_ts = function(data,
                     months = c('july', 'august1',
                                'august2', 'september')) {
  endo_name = "vart"
  exog_name = "medoc_0031"
  ttmp <- cbind(ts_ts(data[, c('period', endo_name)]),
                ts_ts(data[, c('period', exog_name)]))
  for (month in months) {
    ttmp <- cbind(ttmp, ts_ts(data[, c('period', month)]))
  }
  colnames(ttmp) <-
    append(c(endo_name, exog_name), months)
  ttmp[is.na(ttmp)] <- 0
  return(ttmp)
}



launch_reglin <- function(data,
                          exogenous,
                          prediction_period,
                          siren_list,
                          nb_learning_year = 5) {
  pacman::p_load(tsbox)
  

  if(is.null(exogenous))
    return()
  
  pred_period <- seq(
    from = min(prediction_period),
    to = max(max(prediction_period), min(prediction_period) + months(12)),
    by = 'month'
  )
  data <-
    data %>%
    left_join(exogenous,
              by = c('siren', 'period')) %>%
    filter(siren == siren_list,
           period <= max(pred_period),
           period >= (ymd(min(pred_period)) - years(nb_learning_year)))
  
  data2 <- data %>%
    full_join(data.frame(period = pred_period),
              by = 'period') %>%
    mutate(
      year = year(period),
      july = case_when((
        month(period) == 7 & (medoc_0031 == 0 | is.na(medoc_0031))
      ) ~ 1,
      TRUE ~ 0),
      august1 = case_when((month(period) == 8 &
                             ((lag(medoc_0031) == 0) | is.na(lag(medoc_0031))
                             )) ~ 1,
                          TRUE ~ 0),
      august2 = case_when((month(period) == 8 &
                             ((medoc_0031 == 0) | is.na(medoc_0031)
                             )) ~ 1,
                          TRUE ~ 0),
      september = case_when((month(period) == 9 &
                               ((lag(medoc_0031) == 0) | is.na(lag(medoc_0031))
                               )) ~ 1,
                            TRUE ~ 0)
    )
  
  
  data <- create_ts(data2)
  model <- try(lm(as.formula(paste('vart',
                                   paste(
                                     c('medoc_0031',
                                       'july',
                                       'august1',
                                       'august2',
                                       'september'),
                                     collapse = '+'
                                   ),
                                   sep = '~')),
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
        siren = rep(siren_list, length(pred_period)),
        period = pred_period,
        prediction = predict(model, newdata = window(data, start = c(
          year(min(pred_period)),
          month(min(pred_period))
        )))
      )
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
  
  prediction <- pred %>%
    filter(period %in% prediction_period) %>%
    mutate(prediction, method = "launch_reglin")
  return(prediction$prediction)
  }


