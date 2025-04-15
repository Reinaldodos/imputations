

# partie 1 : les series ----------------------------------------------------

# creer les requetes

# voir partie launch_request






# partie 2 : les modèles --------------------------------------------------


# prendre la valeur CA3
taking_exog = function(object, prediction_period, siren) {
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






# tester la methode


# prendre la valeur de l'ER

taking_ER = function(object, prediction_period, siren) {
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


# faire le sarima

launch_sarima = function(object,
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

  
  
