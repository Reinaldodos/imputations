library(dplyr)
library(lubridate)
library(stringr)

MSD_treatment <- function(MSD_file) {
  MSD_data <- data.frame()

  for (file in MSD_file$files) {
    data <-
      rio::import(
        file = file.path(MSD_file[MSD_file$files == file, ]$directory, file),
        na.strings = "",
        row.names = NULL,
        skip = MSD_file[MSD_file$files == file, ]$skiprows,
        encoding = MSD_file[MSD_file$files == file, ]$encoding
      ) %>%
      as_tibble()

    if (MSD_file[MSD_file$files == file, ]$debadmin) {
      colnames(data) <- colnames(data)[2:ncol(data)]
      data <- data[, -ncol(data)]
    }

    MSD_data <-
      data %>%
      mutate(
        siren = str_sub(
          string = TVA,
          start = -9,
          end = -1
        ),
        period = make_date(
          year = as.integer(`Ann?e`),
          month = as.integer(Mois),
          day = 1
        )
      ) %>%
      bind_rows(MSD_data)
  }

  MSD_data %>%
    group_by(siren, Flux) %>%
    summarise(
      period = unique(period),
      .groups = "drop"
    ) %>%
    return()
}
