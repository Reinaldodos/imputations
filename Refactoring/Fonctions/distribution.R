distribution <- function(estim_result,
                         data_distribution,
                         sirens = "all",
                         ventil_imput = 'all',
                         ventil_output = NULL,
                         nbproc = 10,
                         lag_width = 1,
                         endo_name) {
  group <- define_grouping(data_distribution, ventil_imput, endo_name)
  
  selected_sirens <- define_sirens(estim_result, sirens)
  
  distribution <- create_distribution(data_distribution, selected_sirens, group, endo_name)
  
  dist <- compute_dist(distribution, estim_result)
  
  dist_prediction <- calculate_dist_prediction(dist, distribution, estim_result, selected_sirens)
  
  if (is.null(ventil_output)) {
    return(dist_prediction)
  } else {
    return(aggregate_dist_output(dist_prediction, ventil_output))
  }
}

# Fonctions auxiliaires

define_grouping <- function(data_distribution,
                            ventil_imput,
                            endo_name) {
  if (ventil_imput == 'all') {
    setdiff(names(data_distribution), endo_name)
  } else {
    c('siren', 'period', ventil_imput)
  }
}

define_sirens <- function(estim_result, sirens) {
  if (sirens == "all") {
    unique(estim_result$siren)
  } else {
    sirens
  }
}

create_distribution <- function(data_distribution,
                                selected_sirens,
                                group,
                                endo_name) {
  data_distribution %>%
    dplyr::filter(siren %in% selected_sirens) %>%
    dplyr::group_by_at(group) %>%
    dplyr::summarise(endo = sum(!!rlang::sym(endo_name), na.rm = TRUE)) %>%
    dplyr::group_by(siren, period) %>%
    dplyr::mutate(sum_endo = sum(endo, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(ratio = endo / sum_endo)
}

compute_dist <- function(distribution, estim_result) {
  distribution %>%
    dplyr::group_by(siren) %>%
    dplyr::summarise(period = unique(period)) %>%
    dplyr::bind_rows(estim_result %>% dplyr::select(siren, period)) %>%
    dplyr::arrange(siren, period) %>%
    dplyr::group_by(siren) %>%
    dplyr::mutate(period_last = dplyr::lag(period)) %>%
    dplyr::ungroup()
}

calculate_dist_prediction <- function(dist,
                                      distribution,
                                      estim_result,
                                      selected_sirens) {
  estim_result %>%
    dplyr::filter(siren %in% selected_sirens) %>%
    dplyr::left_join(dist, by = c('siren', 'period')) %>%
    dplyr::left_join(
      distribution,
      by = c('siren', 'period_last' = 'period'),
      suffix = c('_imput', '_ventil')
    ) %>%
    dplyr::mutate(dist_prediction = prediction * ratio)
}

aggregate_dist_output <- function(dist_prediction, ventil_output) {
  dist_prediction %>%
    dplyr::group_by_at(c('period', ventil_output)) %>%
    dplyr::summarise(dist_prediction = sum(dist_prediction, na.rm = TRUE))
}
