
estimNR <- function(flow,
                    reg_exped,
                    endogenous,
                    exogenous,
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
  group_siren <- get_group_siren(
    flow,
    reg_exped,
    endogenous,
    exogenous,
    siren,
    prediction_period,
    ref_period,
    nb_learning_year
  )
  
  prediction <- group_siren %>%
    split(.$method_ref) %>%
    map(
      ~ apply_method(
        .x,
        flow,
        prediction_period,
        learning_first,
        nbproc,
        alternative,
        nb_learning_year
      )
    ) %>%
    bind_rows()
  
  prediction <- prediction %>%
    mutate(prediction = case_when(
      na_imput & is.na(prediction) ~ 0,
      negative_imput & prediction < 0 ~ 0,
      TRUE ~ prediction
    ))
  
  if (get_method_ref) {
    prediction <- prediction %>%
      left_join(group_siren %>%
                  select(siren, method_ref), by = "siren")
  }
  
  return(prediction)
}

get_group_siren <- function(flow,
                            reg_exped,
                            endogenous,
                            exogenous,
                            siren,
                            prediction_period,
                            ref_period,
                            nb_learning_year) {
  if (flow == 'E' & reg_exped == 29) {
    endogenous %>%
      filter(siren %in% siren) %>%
      group_by(siren) %>%
      summarise(
        nobs = sum(period < (ymd(
          min(prediction_period)
        ) - years(1)) & !!sym(flow) > 0),
        method_ref = if_else(
          nobs >= 12 * nb_learning_year,
          'launch_sarima',
          'taking_last_year'
        )
      )
  } else {
    endogenous %>%
      filter(siren %in% siren) %>%
      left_join(exogenous %>%
                  filter(siren %in% siren),
                by = c('siren', 'period')) %>%
      group_by(siren) %>%
      summarise(
        notna_exog = sum(!is.na(!!sym(flow))),
        nobs = sum(period < (ymd(
          min(prediction_period)
        ) - years(1))),
        method_ref = case_when(
          nobs == 0 & notna_exog > 0 ~ 'taking_exog',
          nobs == 0 & notna_exog == 0 ~ 'taking_mean',
          nobs < 12 * nb_learning_year &
            notna_exog == 0 ~ 'taking_last_year',
          nobs >= 12 * nb_learning_year &
            notna_exog == 0 ~ 'launch_sarima',
          TRUE ~ 'launch_reglin'
        )
      )
  }
}

apply_method <- function(group_siren,
                         flow,
                         prediction_period,
                         learning_first,
                         nbproc,
                         alternative,
                         nb_learning_year) {
  siren_list <- group_siren$siren
  method_ref <- group_siren$method_ref[1]
  
  do.call(
    get(method_ref),
    prepare_args_for_method(
      method_ref,
      flow,
      prediction_period,
      learning_first,
      siren_list,
      nbproc,
      alternative,
      nb_learning_year
    )
  )
}

prepare_args_for_method <- function(method_ref,
                                    flow,
                                    prediction_period,
                                    learning_first,
                                    siren_list,
                                    nbproc,
                                    alternative,
                                    nb_learning_year) {
  if (method_ref == "taking_last_year") {
    list(flow, prediction_period, siren_list, alternative)
  } else if (method_ref == "launch_sarima") {
    list(flow,
         prediction_period,
         learning_first,
         siren_list,
         nbproc,
         alternative)
  } else {
    list(flow,
         prediction_period,
         siren_list,
         nb_learning_year,
         nbproc,
         alternative)
  }
}
