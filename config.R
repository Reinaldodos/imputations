pacman::p_load(tidyverse)

c(
  "programs/Input.R",
  "Refactoring/tests.R"
) %>%
  walk(
    .f = source,
    encoding = "UTF-8"
  )

# DATE ------------------------------------------------------

date_ref <- as_date("2024-05-01")
nb_date_prediction <- 2
first_publication_date <- as_date("2022-01-01")
date_prediction <- seq.Date(
  from = date_ref - months(nb_date_prediction),
  to = date_ref,
  by = "month"
)
date_publication <- seq.Date(
  from = first_publication_date,
  to = date_ref,
  by = "month"
)
learning_from <- date_ref - years(11)

# PARAMETERS ------------------------------------------------------

## Number of processes to be used ------------------------------------------------------
nbproc <- 10

## Number of years for linear regression ------------------------------------------------------
nb_years_regressions <- 5

## First few years of input data :
### T : from historical basis
### F : from first extraction
use_historical_basis <- F

## Do you want to save input files in historical basis ?
save_historical_input <- T

## Use Gazelec file from reglementation ?
use_gazelec_file <- T

## Add gazelec data to the last result ?
add_gazelec_data <- T


imput_filename_format <- sprintf(
  "estim_%s_%s_ref%s.csv", "%s", "%s",
  format(date_ref, "%Y%m")
)
ventil_filename_format <- sprintf(
  "ventil_%s_ref%s.csv", "%s",
  format(date_ref, "%Y%m")
)


################################################################################
#                                    DIRECTORY                                 #
################################################################################

input_directory <- "input"
ETL_directory <- "ETL"
pipeline_directory <- "pipeline"
output_directory <- "output_PC"
freenas_directory <- "Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI"
dir.create(output_directory, showWarnings = F)

output_freenas_directory <- file.path(
  freenas_directory,
  "traitement non-réponse",
  sprintf(
    "production_%s",
    format(date_ref, "%Y%m")
  ),
  output_directory
)
dir.create(output_freenas_directory, showWarnings = F)

historical_directory <- file.path(
  freenas_directory,
  "traitement non-réponse",
  "historique"
)
# historical_directory <- '../historique/'

sample_directory <- c(
  file.path(
    freenas_directory,
    "échantillon",
    "échantillon_202201",
    "datas"
  ),
  file.path(
    freenas_directory,
    "échantillon",
    "échantillon_202301"
  ),
  file.path(
    freenas_directory,
    "échantillon",
    "échantillon_202401"
  )
)

date_sample <- c(
  first_publication_date,
  as.Date("2023-01-01"),
  as.Date("2024-01-01")
)


################################################################################
#                                      FILES                                   #
################################################################################

sample_file <- data.frame(
  directory = sample_directory, 
  files = c("2022_FE_1_2022M032EC-s5v18.csv",
            "2023_FE_4_8.5_20240115.csv",
            "2024_FE_1_1.5_20240612.csv"), 
  encoding = "UTF-8", 
  date_beg = date_sample,
  dec = ",",
  skiprows = 0
)


msd_file <- data.frame(
  directory = input_directory,
  files = sprintf(
    "listeMoisSansDeclaration_%s.csv",
    format(date_publication, "%Y%m")
  ),
  # format(today(), "%Y-%m-%d")),
  encoding = "UTF-8",
  debadmin = F
) %>%
  mutate(skiprows = ifelse(debadmin, 4, 0))

test_MSD_fichiers_presents(msd_file = msd_file)

intro_imput_file <- data.frame(
  directory = c(
    input_directory,
    "Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI//traitement non-réponse/production_202201/input/"
  ),
  files = c(
    sprintf(
      "intro_imput_%s-%s.csv",
      year(date_ref - years(4)),
      year(date_ref)
    ),
    "intro_imput_2011-2022_extract20220222.zip"
  ),
  encoding = "UTF-8",
  skiprows = c(
    18,
    25
  ),
  dec = ",",
  start = c(
    date_ref - years(4),
    learning_from
  ),
  end = c(
    date_ref,
    date_ref - years(4) - months(1)
  ),
  historical = c(F, F),
  astrineo_input = c(T, T)
)


exped_imput_file <- data.frame(
  directory = c(
    input_directory,
    "Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI//traitement non-réponse/production_202201/input/"
  ),
  files = c(
    sprintf(
      "exped_imput_%s-%s.csv",
      year(date_ref - years(4)),
      year(date_ref)
    ),
    "exped_imput_2011-2022_extract20220222.zip"
  ),
  encoding = "UTF-8",
  skiprows = c(
    17,
    25
  ),
  dec = ",",
  start = c(
    date_ref - years(4),
    learning_from
  ),
  end = c(
    date_ref,
    date_ref - years(4) - months(1)
  ),
  historical = c(F, F),
  astrineo_input = c(T, T)
)



intro_ventil_file <- data.frame(
  directory = input_directory,
  files = c(
    "intro_ventil_2021.csv", "intro_ventil_2022.csv",
    "intro_ventil_2023.csv", "intro_ventil_2024.csv"
  ),
  encoding = "UTF-8",
  skiprows = 0,
  dec = ",",
  start = c(
    as_date("2021-01-01"),
    as_date("2022-01-01"),
    as_date("2023-01-01"),
    as_date("2024-01-01")
  ),
  end = date_ref,
  astrineo_input = T
)


exped_ventil_file <- data.frame(
  directory = input_directory,
  files = c(
    sprintf(
      "exped_ventil_%s-%s.csv",
      year(date_ref - years(3)),
      year(date_ref - years(2))
    ),
    sprintf(
      "exped_ventil_%s-%s.csv",
      year(date_ref - years(1)),
      year(date_ref)
    )
  ),
  encoding = "UTF-8",
  skiprows = 15,
  dec = ",",
  start = c(date_ref - years(3), date_ref - years(1)),
  end = date_ref,
  astrineo_input = T
)


ER_file <- data.frame(
  directory = input_directory,
  files = sprintf(
    "ER_exped_%s.csv",
    paste0(year(date_ref - years(2)), "-", year(date_ref))
  ),
  encoding = "UTF-8",
  skiprows = 15,
  dec = ",",
  start = date_ref - months(3),
  end = date_ref,
  astrineo_input = T
)


ca3_file <- data.frame(
  files = c("Donnees_mensuelles.csv"),
  directory = input_directory
)

base_CA3 <- "~/dsece-imputation-nr/CA3 Parquet/"

test_last_CA3(base_CA3 = base_CA3, date_ref = date_ref)

gazelec_file <- data.frame(
  files = sprintf("DEB_gazélec_%s.xlsx", format(date_ref, "%Y%m")),
  directory = input_directory,
  skiprows = 3
)

pass_names <- c("annee", "ngp9", "cpf6", "a17", "a38", "a129", "cpfrev1", "nes114", "ctci")

pass_file <- data.frame(
  files = c("11- fichier POLYCO2021.xls", "11- POLYCO2022.xls", "11_POLYCO2023_b.xlsx", "11_POLYCO2024_b.xlsx"),
  skiprows = 1,
  directory = c("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/data"),
  year = c(2021, 2022, 2023, 2024),
  cols = "A:I"
)

y <- unique(year(date_publication))
cniv_file <- data.frame(
  files = c(
    "Extraction de la table Nomenc viti 2023_12.csv",
    "Table Inter viti 2022 avec clients prod INES.xls",
    "EXPORTATIONS_DEB-DAU_CNIV.xlsx",
    sprintf(
      "vin-spiritueux_%s.csv",
      c(min(y) - 1, max(y)) %>% as.character() %>% paste(collapse = "-")
    )
  ),
  directory = c(
    rep(file.path(freenas_directory, "traitement non-réponse", "data"), 3),
    input_directory
  ),
  type = c("confederation_to_ngp", "client", "reference", "input"),
  skiprows = c(0, 1, 0, 15),
  start = make_date(year = min(y) - 1, month = 1, day = 1),
  end = date_ref,
  astrineo_input = c(F, F, F, T)
)
