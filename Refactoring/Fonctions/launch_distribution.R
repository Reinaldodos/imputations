launch_distribution <- function(imput_result,
                                date,
                                detail_data,
                                endo_name) {
  result <- imput_result %>%
    dplyr::filter(period == lubridate::as_date(date))
  
  distribution_result <- perform_distribution(result, detail_data, endo_name)
  
  return(distribution_result)
}

perform_distribution <- function(result, detail_data, endo_name) {
  sirens <- unique(result$siren)
  data_cols <- c(
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
    endo_name
  )

  source(file = "Refactoring/Fonctions/distribution.R")
  
  distribution(
    estim_result = result,
    data_distribution = detail_data[, data_cols],
    sirens = sirens,
    endo_name = endo_name
  )
}
