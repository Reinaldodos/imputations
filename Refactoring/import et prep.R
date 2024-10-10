dir.create(path = ETL_directory)

# ETL samples -----------------------------------------------------------------

source(file = "Refactoring/Fonctions/import_samples_transform.R",
       encoding = "UTF-8")

sample_file %>%
  import_samples_transform(colClasses = Classes) %>%
  arrow::write_feather(sink = file.path(
    ETL_directory,
    "echantillon.arrow"
  ))

gc(full = TRUE)

# ETL delete data -----------------------------------------------------------------

source(file = "Refactoring/Fonctions/ETL_delete_data.R",
       encoding = "UTF-8")

ETL_delete_data(
  sample_file = sample_file,
  ETL_directory = ETL_directory,
  chemin_historique = file.path(
    historical_directory,
    "delete.rds"
  )
)

gc(full = TRUE)

# ETL MSD -----------------------------------------------------------------

source(file = "Refactoring/Fonctions/import_msd.R",
       encoding = "UTF-8")

msd_file %>%
  import_msd() %>%
  arrow::write_feather(sink = file.path(
    ETL_directory,
    "MSD.arrow"
  ))

gc(full = TRUE)