# Chargez les bibliothèques nécessaires
library(rio)
library(dplyr)
library(janitor)
library(lubridate)
library(rlang)

# Sous-fonction pour construire la condition de filtrage
build_condition <-
  function(start_date,
           end_date,
           total_variable,
           astrineo_input,
           ...) {
    period_condition <- sprintf(
      "(period >= '%s') & (period <= '%s')",
      format(start_date, "%Y-%m-%d"),
      format(end_date, "%Y-%m-%d")
    )
    
    if (astrineo_input) {
      extra_condition <- sprintf("%s != 'Total Général'", total_variable)
      return(c(extra_condition, period_condition, ...))
    }
    
    return(period_condition)
  }

# Sous-fonction pour importer et nettoyer les données
import_and_clean_data <-
  function(file_path,
           col_classes,
           skiprows,
           encoding,
           dec,
           ...) {
    data <- import(
      file_path,
      colClasses = col_classes,
      na.strings = "",
      skip = skiprows,
      encoding = encoding,
      dec = dec,
      ...
    )
    clean_data <- data %>%
      clean_names() %>%
      as_tibble()
    return(clean_data)
  }

# Sous-fonction pour filtrer et renommer les colonnes des données
filter_and_rename_data <- function(data, condition, rename_list) {
  filtered_data <- data %>%
    mutate(period = make_date(
      year = adep,
      month = mdep,
      day = 1
    )) %>%
    filter(!!!parse_exprs(condition)) %>%
    rename(all_of(rename_list))
  return(filtered_data)
}

# Fonction principale
data_treatment_v2 <-
  function(file_path,
           start_date,
           end_date,
           rename_list,
           total_variable,
           astrineo_input,
           col_classes,
           skiprows,
           encoding,
           dec,
           ...) {
    condition <-
      build_condition(start_date, end_date, total_variable, astrineo_input, ...)
    data <-
      import_and_clean_data(file_path, col_classes, skiprows, encoding, dec)
    towards_data <-
      filter_and_rename_data(data, condition, rename_list)
    return(towards_data)
  }
