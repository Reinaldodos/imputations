library(dplyr)
library(tidyr)
library(purrr)
library(lubridate)

use_historical_data <- function(current_imput_data,
                                use_historical_basis,
                                historical_directory,
                                flow_name,
                                date_ref) {
  if (use_historical_basis) {
    historical_imput_data <- read_historical_data(
      historical_directory = historical_directory,
      filename = sprintf("endogenous_%s.rds", flow_name),
      date_ref = date_ref
    )
    imput_data <- bind_rows(historical_imput_data, current_imput_data)
  } else {
    imput_data <- current_imput_data
  }
  return(imput_data)
}

# Traitement des données
prepare_imput_data <- function(source_file,
                               flow_name,
                               variable,
                               delete_data,
                               sample,
                               flow,
                               use_historical_basis,
                               historical_directory,
                               date_ref) {
  read_current_data(source_file = source_file) %>%
    use_historical_data(
      use_historical_basis = use_historical_basis,
      historical_directory = historical_directory,
      flow_name = flow_name,
      date_ref = date_ref
    ) %>%
    process_imput_data(delete_data = delete_data, variable = variable) %>%
    add_missing_sirens(sample = sample,
                       flow = flow,
                       date_ref = date_ref)
}

# Écriture des données
save_data <- function(data, path) {
  saveRDS(data, path)
}

# Sous-fonctions auxiliaires
get_flow_name <- function(flow) {
  flow_dict <- data.frame(
    flow = c("E", "I"),
    flow_name = c("exped", "intro"),
    variable = c("regdem", NA)
  )
  flow_dict %>%
    filter(flow == !!flow) %>%
    pull(flow_name)
}

get_variable_list <- function(flow) {
  flow_dict <- data.frame(
    flow = c("E", "I"),
    flow_name = c("exped", "intro"),
    variable = c("regdem", NA)
  )
  na.omit(c(
    "siren_new",
    "period",
    flow_dict %>% filter(flow == !!flow) %>% pull(variable)
  ))
}

read_historical_data <- function(historical_directory, filename, date_ref) {
  readRDS(file.path(historical_directory, filename)) %>%
    filter(period >= (date_ref - years(11)) &
             period <= (date_ref - years(3) - months(1)))
}

read_current_data <- function(source_file) {
  source_file$files %>%
    map(~ data_treatment(
      source_file,
      .x,
      total_variable = "sire",
      rename_list = c("siren" = "sire")
    ), .progress = TRUE) %>%
    bind_rows()
}

process_imput_data <- function(imput_data, delete_data, variable) {
  imput_data %>%
    left_join(delete_data, by = "siren") %>%
    rowwise() %>%
    mutate(
      siren_new = ifelse(is.na(siren_repreneur), siren, siren_repreneur),
      vart_new = ifelse(is.na(ratio), vart, vart * ratio)
    ) %>%
    ungroup() %>%
    group_by(across(all_of(variable))) %>%
    summarise(vart = sum(vart_new, na.rm = TRUE)) %>%
    ungroup() %>%
    rename(siren = siren_new)
}

add_missing_sirens <- function(imput_data, sample, flow, date_ref) {
  sirens_extra <- sample %>%
    filter(!siren %in% imput_data$siren) %>%
    select(siren) %>%
    distinct() %>%
    pull(siren)
  
  if (flow == "I") {
    bind_rows(imput_data,
              data.frame(
                siren = sirens_extra,
                period = date_ref,
                vart = NA
              ))
  } else {
    bind_rows(imput_data,
              data.frame(
                siren = rep(sirens_extra, 2),
                period = date_ref,
                regdem = rep(c("21", "29"), each = length(sirens_extra)),
                vart = NA
              )) %>%
      pivot_wider(
        names_from = regdem,
        values_from = vart,
        names_prefix = "vart_",
        values_fill = list(vart = 0)
      )
  }
}

# Fonction principale

import_endogenous <- function(source_file,
                              flow,
                              sample,
                              delete_data,
                              historical_directory,
                              input_directory,
                              save_historical_input) {
  flow_name <- get_flow_name(flow)
  filename <- sprintf("endogenous_%s.rds", flow_name)
  variable <- get_variable_list(flow)
  input_path <- file.path(input_directory, filename)
  historical_path <- file.path(historical_directory, filename)

  imput_data <- prepare_imput_data(
    source_file = source_file,
    flow_name = flow_name,
    variable = variable,
    delete_data = delete_data,
    sample = sample,
    flow = flow,
    use_historical_basis = use_historical_basis,
    historical_directory = historical_directory,
    date_ref = date_ref)
  
  if (save_historical_input) {
    save_data(imput_data, historical_path)
  }
  
  return(imput_data)
}
