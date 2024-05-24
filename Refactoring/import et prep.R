
dir.create(path = ETL_directory)

# ETL samples

sample_file %>% 
  import_samples_transform(colClasses = Classes) %>% 
  arrow::write_feather(sink = file.path(ETL_directory,
                                        "echantillon.arrow"))
# ETL delete data

ETL_delete_data(
  sample_file = sample_file,
  ETL_directory = ETL_directory,
  chemin_historique = file.path(historical_directory,
                                "delete.rds")
)


# ETL MSD -----------------------------------------------------------------
msd_file %>% 
  import_msd() %>% 
  arrow::write_feather(sink = file.path(ETL_directory,
                                        "MSD.arrow"))


# ETL CA3 -----------------------------------------------------------------

import_ca3(base_CA3 = base_CA3,
           sample_intro = sample_intro,
           delete_data = delete) %>% 
  arrow::write_feather(sink = file.path(ETL_directory,
                                        "exogenous_intro.arrow"))

