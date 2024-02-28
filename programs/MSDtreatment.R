library(dplyr)
library(lubridate)
library(stringr)

MSD_treatment <- function(MSD_file){
  MSD_data <- data.frame()
  for (file in MSD_file$files){
    data <- as_tibble(rio::import(
      file = file.path(MSD_file[MSD_file$files == file,]$directory, file),
      na.strings = "", row.names = NULL,
      skip = MSD_file[MSD_file$files == file,]$skiprows, 
      encoding = MSD_file[MSD_file$files == file,]$encoding
    ))
    if (MSD_file[MSD_file$files == file,]$debadmin){
      colnames(data) <- colnames(data)[2:ncol(data)]
      data <- data[ , - ncol(data)]
    }
    MSD_data <- rbind(
      MSD_data, 
      data
      %>% mutate(siren = str_sub(TVA, start = -9, end = -1),
                 period = make_date(year = as.integer(`Année`), month = as.integer(Mois), day = 1))
    )
  }
  # MSD <- (MSD_data 
  #         %>% group_by(siren, Flux, period)
  #         %>% summarise(MSD = if_else(is.na(max(`Date.dépôt.DEB`)), true = 1, false = 0)))
  MSD <- MSD_data %>%
    group_by(siren, Flux) %>%
    summarise(period = unique(period)) %>%
    ungroup()
  return(MSD)
}