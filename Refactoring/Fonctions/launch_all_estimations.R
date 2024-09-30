launch_all_estimations <- function(flow_name,
                                   dates,
                                   sample,
                                   output_directory,
                                   learning_from,
                                   nb_years_regressions = 5,
                                   nbproc = 5) {
  filename <- file.path(output_directory, str_glue("{flow_name}_imput.rds"))
  
  imput_data <- load_or_compute_data(
    filename,
    dates,
    flow_name,
    sample,
    output_directory,
    learning_from,
    nb_years_regressions,
    nbproc
  )
  
  return(imput_data)
}

load_or_compute_data <- function(filename,
                                 dates,
                                 flow_name,
                                 sample,
                                 output_directory,
                                 learning_from,
                                 nb_years_regressions,
                                 nbproc) {
  if (file.exists(filename)) {
    imput_data <- readRDS(filename)
  } else {
    imput_data <- compute_data(
      dates,
      flow_name,
      sample,
      output_directory,
      learning_from,
      nb_years_regressions,
      nbproc
    )
    saveRDS(imput_data, filename)
  }
    return(imput_data)
}

compute_data <- function(dates,
                         flow_name,
                         sample,
                         output_directory,
                         learning_from,
                         nb_years_regressions,
                         nbproc) {
  
  source(file = "Refactoring/Fonctions/launch_estimation.R")
  
  imput_data <- dates %>%
    purrr::map(
      .f =  ~ launch_estimation(
        flow_name = flow_name,
        date = .x,
        sample = sample,
        output_directory = output_directory,
        learning_from = learning_from,
        nb_years_regressions = nb_years_regressions,
        nbproc = nbproc
      )
    ) %>%
    bind_rows()
  
  return(imput_data)
}
