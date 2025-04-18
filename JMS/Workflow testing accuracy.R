library(tidyverse)

# mapping des modèles selon le flux

modeles <-
  list(
    crossing(
      flux = "expe",
      regdem = "21",
      model = c(
        "taking_ER",
        "launch_sarima",
        "taking_last_year",
        "taking_mean"
      )
    ),
    crossing(
      flux = "expe",
      regdem = "29",
      model = c("launch_sarima",
                "taking_last_year",
                "taking_mean")
    ),
    crossing(
      flux = "intro",
      regdem = c("all"),
      model = c(
        "launch_reglin",
        "taking_exog",
        "launch_sarima",
        "taking_last_year",
        "taking_mean"
      )
    )
  ) %>%
  bind_rows()
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
