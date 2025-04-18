library(tidyverse)

# mapping des modèles selon le flux

modeles <-
  tribble(
    ~model,
    ~flux,
    "taking_exog",
    "intro",
    "taking_ER",
    "intro + expe",
    "launch_sarima",
    "intro + expe",
    "taking_last_year",
    "expe",
    "taking_mean",
    "intro + expe",
    "launch_reglin",
    "intro + expe"
  ) %>%
  tidyr::separate(col = flux, into = c("intro", "expe"), sep = " \\+ ") %>%
  pivot_longer(
    cols = c(intro, expe),
    names_to = "TOTO",
    values_to = "flux",
    values_drop_na = TRUE
  ) %>%
  select(-TOTO)


# importer les fichiers à utiliser:
input <-
  list(
    endogenous %>%
      group_nest(siren, flux, .key = "data"),
    exogenous %>%
      group_nest(siren, .key = "ca3") %>%
      mutate(flux = "intro"),
    modeles
  ) %>%
  reduce(.f = left_join)
