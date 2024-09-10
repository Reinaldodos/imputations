

launch_estimation <- function(flow_name,
                              date,
                              sample,
                              output_directory,
                              date_ref,
                              learning_from,
                              nb_years_regressions,
                              nbproc = 5) {
  siren_imput <- get_siren_imput(sample, endogenous, date)
  
  str_glue(
    "Flow {flow_name}, Date {format(as_date(date), '%Y-%m')}, Siren count: {length(siren_imput)}"
  ) %>%
    message()
  
  imput_data <- estimate_imputation(
    flow_name,
    date,
    output_directory,
    date_ref,
    siren_imput,
    learning_from,
    nb_years_regressions,
    nbproc
  )
  
  save_imputation_data(imput_data, flow_name, date, output_directory, date_ref)
  return(imput_data)
}

estimate_imputation <- function(flow_name,
                                date,
                                output_directory,
                                date_ref,
                                siren_imput,
                                learning_from,
                                nb_years_regressions,
                                nbproc) {
  
  source(file = "Refactoring/Fonctions/estimNR.R")
  
  imput_data <- estimNR(
    flow_name = flow_name,
    prediction_period = as_date(date),
    ref_period = as_date(date_ref),
    siren = siren_imput,
    learning_first = learning_from,
    get_method_ref = TRUE,
    nbproc = nbproc,
    nb_learning_year = nb_years_regressions
  )
  return(imput_data)
}

get_siren_imput <- function(sample, endogenous, date) {
  get_NR_list(sample, endogenous = endogenous, date = date) %>%
    pull(siren)
}

save_imputation_data <- function(imput_data,
                                 flow_name,
                                 date,
                                 output_directory,
                                 date_ref) {
  file_path <- file.path(
    output_directory,
    str_glue(
      "estim_{flow_name}_{format(as_date(date), '%Y%m')}_ref{format(as_date(date_ref), '%Y%m')}.rds"
    )
  )
  saveRDS(imput_data, file_path)
}
