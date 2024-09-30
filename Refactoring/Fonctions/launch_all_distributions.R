launch_all_distributions <- function(output_directory,
                                     flow_name,
                                     imput_result,
                                     dates,
                                     detail_data,
                                     endo_name) {
  filename <- file.path(output_directory,
                        stringr::str_glue("{flow_name}_ventil.rds"))
  
  if (file.exists(filename)) {
    distribution_data <- readRDS(filename)
  } else {
    distribution_data <- generate_distributions(imput_result, dates, detail_data, endo_name)
    saveRDS(distribution_data, filename)
  }
  
  return(distribution_data)
}

generate_distributions <- function(imput_result,
                                   dates,
                                   detail_data,
                                   endo_name) {
  
  source(file = "Refactoring/Fonctions/launch_distribution.R")
  
  purrr::map(
    .x = dates,
    .f =  ~ launch_distribution(imput_result, .x, detail_data, endo_name)
  ) %>%
    dplyr::bind_rows()
}
