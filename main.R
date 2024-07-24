options(scipen = 999)


purrr::walk(
  .x = c(
    "config.R"
    # "programs/NR.R",
    # "programs/Production.R",
    # "programs/CNIV.R"
  ),
  .f = source,
  encoding = "UTF-8"
)

gc()
memory.limit(9e12)


# ETL INPUT FILES ---------------------------------------------------------

if (!dir.exists(ETL_directory)) {
  source(
    file = "Refactoring/import et prep.R",
    encoding = "UTF-8",
    echo = TRUE
  )
}

# IMPORT INPUT FILES ------------------------------------------------------

input_object <- Input(
  date_ref = date_ref,
  date_prediction = date_prediction,
  date_publication = date_publication,
  input_directory = input_directory,
  # astrineo = astrineo_input,
  intro_imput = intro_imput_file,
  exped_imput = exped_imput_file,
  intro_ventil = intro_ventil_file,
  exped_ventil = exped_ventil_file,
  ER = ER_file,
  ca3 = ca3_file,
  sample_directory = sample_directory,
  sample = sample_file,
  msd = msd_file,
  historical_directory = historical_directory,
  use_historical_basis = use_historical_basis,
  save_historical_input = save_historical_input,
  use_gazelec_file = use_gazelec_file,
  add_gazelec_data = add_gazelec_data,
  gazelec = gazelec_file,
  output_directory = output_directory,
  output_freenas_directory = output_freenas_directory,
  pass = pass_file,
  cniv = cniv_file
)

sample <- file.path(
  ETL_directory,
  "echantillon.arrow"
) %>%
  arrow::read_feather()

sample_intro <-
  sample %>%
  get_sample_by_flow(flow = "I")

sample_exped <-
  sample %>%
  get_sample_by_flow(flow = "E")

delete <-
  file.path(
    ETL_directory,
    "delete_data.arrow"
  ) %>%
  arrow::read_feather()

msd <-
  file.path(
    ETL_directory,
    "MSD.arrow"
  ) %>%
  arrow::read_feather()

source(file = "Refactoring/Fonctions/import_ca3.R",
       encoding = "UTF-8")

exogenous_intro <-
  import_ca3(
    base_CA3 = base_CA3,
    sample_intro = sample_intro,
    delete_data = delete,
    date_prediction = date_prediction
  )

source(file = "Refactoring/Fonctions/import_detail.R",
       encoding = "UTF-8")

detail_intro <- 
  import_detail(source_file = intro_ventil_file,
                delete_data = delete, 
  condition = "payp %notin% c('XU', 'GB')"
)

detail_exped <-
  import_detail(source_file = exped_ventil_file,
                delete_data = delete,
                condition = "pyod %notin% c('XU', 'GB')")

source(file = "Refactoring/Fonctions/import_endogenous.R",
       encoding = "UTF-8")

endogenous_intro <-
  import_endogenous(
    source_file = intro_imput_file,
    flow = "I",
    sample = sample_intro,
    delete_data = delete,
    historical_directory = historical_directory,
    input_directory = input_directory,
    save_historical_input = save_historical_input
  )

endogenous_exped <-
  import_endogenous(
    source_file = exped_imput_file,
    flow = "E",
    sample = sample_exped,
    delete_data = delete,
    historical_directory = historical_directory,
    input_directory = input_directory,
    save_historical_input = save_historical_input
  )


ER <- import_ER(input_object)

# LAUNCH SIMULATIONS ------------------------------------------------------

## Introduction ------------------------------------------------------

start <- Sys.time()
source("programs/launch_introduction.R")
print(Sys.time() - start)

## Expedition ------------------------------------------------------

start <- Sys.time()
source("programs/launch_expedition.R")
print(Sys.time() - start)

# PRODUCTION ------------------------------------------------------

source("programs/launch_production.R")

source("programs/imputations_NATR.R", encoding = "UTF-8")
source("programs/imputations_transport48Kv2.R", encoding = "UTF-8")
source("programs/prgm_C3290.R")


# CONTROLE ------------------------------------------------------

source("programs/Controles_imput_PC_yb.R")

# CNIV ------------------------------------------------------

source("programs/launch_cniv.R")
