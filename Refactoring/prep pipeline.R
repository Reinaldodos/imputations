dir.create(path = pipeline_directory)

# ETL exogenous -----------------------------------------------------------

source(file = "Refactoring/Fonctions/import_ca3.R",
       encoding = "UTF-8")

exogenous_intro <-
  import_ca3(
    base_CA3 = base_CA3,
    sample_intro = sample_intro,
    delete_data = delete,
    date_prediction = date_prediction
  ) %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "exogenous_intro.arrow"
  ))

gc(full = TRUE)

# ETL detail --------------------------------------------------------------

source(file = "Refactoring/Fonctions/import_detail.R",
       encoding = "UTF-8")

import_detail(source_file = intro_ventil_file,
                delete_data = delete, 
                condition = "payp %notin% c('XU', 'GB')"
  ) %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "detail_intro.arrow"
  ))

import_detail(source_file = exped_ventil_file,
                delete_data = delete,
                condition = "pyod %notin% c('XU', 'GB')") %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "detail_exped.arrow"
  ))

gc(full = TRUE)

# ETL endogenous ----------------------------------------------------------

source(file = "Refactoring/Fonctions/import_endogenous.R",
       encoding = "UTF-8")

import_endogenous(
    source_file = intro_imput_file,
    flow = "I",
    sample = sample_intro,
    delete_data = delete,
    historical_directory = historical_directory,
    input_directory = input_directory,
    save_historical_input = save_historical_input
  ) %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "endogenous_intro.arrow"
  ))

import_endogenous(
    source_file = exped_imput_file,
    flow = "E",
    sample = sample_exped,
    delete_data = delete,
    historical_directory = historical_directory,
    input_directory = input_directory,
    save_historical_input = save_historical_input
  ) %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "endogenous_exped.arrow"
  ))

gc(full = TRUE)

# Etats récapitulatifs (ER) -----------------------------------------------

import_ER(ER_file = ER_file, 
          delete_data = delete) %>% 
  arrow::write_feather(sink = file.path(
    pipeline_directory,
    "etats_recap.arrow"
  ))

gc(full = TRUE)