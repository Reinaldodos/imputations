# Load necessary packages
library(dplyr)
library(janitor)
library(lubridate)

# Sub-functions
connect_and_clean <- function(base_CA3) {
  base_CA3 %>%
    connect_to_last_ca3() %>%
    select(SIREN, PERIODE, Medoc_0031) %>%
    collect() %>%
    clean_names()
}

create_period <- function(ca3_data) {
  ca3_data %>%
    mutate(period = make_date(
      year = as.integer(substr(periode, 1, 4)),
      month = as.integer(substr(periode, 5, 6)),
      day = 1
    ))
}

filter_data <- function(ca3_data, sample_intro, delete_data, date_prediction) {
  ca3_data %>%
    filter(
      period >= (min(date_prediction) - years(5)) &
        (siren %in% sample_intro$siren | siren %in% delete_data$siren)
    )
}

join_and_mutate <- function(ca3_data, delete_data) {
  ca3_data %>%
    left_join(y = delete_data, by = "siren", relationship = "many-to-many") %>%
    mutate(
      siren_new = ifelse(is.na(siren_repreneur), siren, siren_repreneur),
      medoc_0031 = ifelse(is.na(ratio), as.numeric(medoc_0031), as.numeric(medoc_0031) * ratio)
    )
}

summarize_data <- function(ca3_data) {
  ca3_data %>%
    group_by(siren_new, period) %>%
    summarise(medoc_0031 = sum(medoc_0031), .groups = "drop") %>%
    rename(siren = siren_new)
}

# Main function
import_ca3 <- function(base_CA3, sample_intro, delete_data, date_prediction) {
  base_CA3 %>%
    connect_and_clean() %>%
    create_period() %>%
    filter_data(sample_intro, delete_data, date_prediction) %>%
    join_and_mutate(delete_data) %>%
    summarize_data() %>%
    return()
}
