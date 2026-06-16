options(scipen = 999)


purrr::walk(
  .x = c(
    "config.R",
    "programs/Production.R",
    "programs/CNIV.R"
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
  arrow::read_feather() |>
  filter(siren != "405395518") # neutraliser NIKE RETAIL



if (!dir.exists(pipeline_directory)) {
  source(
    file = "Refactoring/prep pipeline.R",
    encoding = "UTF-8",
    echo = TRUE
  )
}

exogenous_intro <-
  file.path(
    pipeline_directory,
    "exogenous_intro.arrow"
  ) %>%
  arrow::read_feather()

detail_intro <-
  file.path(
    pipeline_directory,
    "detail_intro"
  ) %>%
  arrow::open_dataset() %>%
  collect()

detail_exped <-
  file.path(
    pipeline_directory,
    "detail_exped"
  ) %>%
  arrow::open_dataset() %>%
  collect()

endogenous_intro <-
  file.path(
    pipeline_directory,
    "endogenous_intro.arrow"
  ) %>%
  arrow::read_feather()

endogenous_exped <-
  file.path(
    pipeline_directory,
    "endogenous_exped.arrow"
  ) %>%
  arrow::read_feather()

ER <-
  file.path(
    pipeline_directory,
    "etats_recap.arrow"
  ) %>%
  arrow::read_feather()

# LAUNCH SIMULATIONS ------------------------------------------------------

## Introduction ------------------------------------------------------

start <- Sys.time()
source("programs/launch_introduction.R", encoding = "UTF-8")
print(Sys.time() - start)

## Expedition ------------------------------------------------------

start <- Sys.time()
source("programs/launch_expedition.R", encoding = "UTF-8")
print(Sys.time() - start)

# PRODUCTION ------------------------------------------------------

# source("programs/launch_production.R", encoding = "UTF-8")
#
# source("programs/imputations_NATR.R", encoding = "UTF-8")
# source("programs/imputations_transport48Kv2.R", encoding = "UTF-8")
# source("programs/prgm_C3290.R", encoding = "UTF-8")


# CONTROLE ------------------------------------------------------

source("programs/Controles_imput_PC_yb.R", encoding = "UTF-8")

# CNIV ------------------------------------------------------

source("programs/launch_cniv.R", encoding = "UTF-8")
