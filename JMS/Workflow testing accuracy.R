library(tidyverse)



source(file = "JMS/les_modeles.R", echo = FALSE)

date_a_predire <- lubridate::ymd("2025-01-01")

# mapping des modèles selon le flux ---------------------------------------

modeles <-
  list(
    crossing(
      flux = "expe",
      regdem = "21",
      model = c(
        "taking_ER",
        "launch_sarima_refactor",
        "taking_last_year",
        "taking_mean"
      )
    ),
    crossing(
      flux = "expe",
      regdem = "29",
      model = c(
        "launch_sarima_refactor",
        "taking_last_year",
        "taking_mean"
      )
    ),
    crossing(
      flux = "intro",
      regdem = c("all"),
      model = c(
        "launch_reglin",
        "taking_exog",
        "launch_sarima_refactor",
        "taking_last_year",
        "taking_mean"
      )
    )
  ) %>%
  bind_rows()


# Mise en forme des inputs ------------------------------------------------
last_sample <-
  sample %>%
  dplyr::count(date_beg) %>%
  filter(date_beg <= date_a_predire) %>%
  top_n(n = 1, wt = date_beg) %>%
  semi_join(x = sample)

echantillon <-
  last_sample %>%
  select(siren, starts_with("deb_")) %>%
  pivot_longer(
    cols = starts_with("deb_"),
    names_to = "flux",
    values_to = "TOTO",
    names_prefix = "deb_"
  ) %>%
  filter(TOTO == 1) %>%
  select(-TOTO)

endogenous_repondants <-
  list(
    "intro" =
      endogenous_intro %>%
        mutate(regdem = "all"),
    "expe" = endogenous_exped %>%
      pivot_longer(
        cols = starts_with("vart_"),
        names_to = "regdem",
        values_to = "vart",
        names_prefix = "vart_"
      ) %>%
      filter(vart > 0)
  ) %>%
  bind_rows(.id = "flux")

msd_vart <-
  list(
    endogenous_repondants %>%
      distinct(flux, regdem),
    msd %>%
      drop_na() %>%
      transmute(siren, period,
        flux = str_to_lower(Flux),
        vart = 0
      )
  ) %>%
  reduce(
    .f = inner_join,
    by = join_by(flux)
  )

endogenous <- bind_rows(endogenous_repondants, msd)

exogenous <-
  list(
    "intro" = exogenous_intro,
    "expe" = ER
  ) %>%
  bind_rows(.id = "flux")

# importer les fichiers à utiliser ----------------------------------------

cut_exogenous_if_reglin <- function(model, exogenous, prediction_period) {
  if (model == "launch_reglin" && !is.null(exogenous)) {
    exogenous <-
      exogenous %>%
      filter(period < prediction_period)
  }
  return(exogenous)
}

input <-
  list(
    endogenous %>%
      filter(period < date_a_predire) %>%
      group_nest(siren, flux, regdem,
        .key = "data",
        keep = TRUE
      ),
    exogenous %>%
      filter(period <= date_a_predire) %>%
      group_nest(siren, flux,
        .key = "exogenous",
        keep = TRUE
      ),
    modeles
  ) %>%
  reduce(.f = left_join) %>%
  semi_join(
    y = echantillon,
    by = join_by(siren, flux)
  ) %>%
  mutate(
    prediction_period = date_a_predire,
    exogenous = pmap(
      .f = cut_exogenous_if_reglin,
      .l = list(
        model = model,
        exogenous = exogenous,
        prediction_period = prediction_period
      ),
      .progress = TRUE
    )
  )


# Construire une factory d'appel dynamique des modèles --------------------

launch_model <- function(model,
                         data,
                         exogenous,
                         prediction_period,
                         siren) {
  # Charge l'ensemble des modèles dans l'environnement
  source("~/imputations/JMS/les_modeles.R", encoding = "UTF-8")

  # Récupère la fonction à partir de son nom (string)
  model_fn <- get(model)

  # Appelle la fonction dynamiquement
  if (model %in% c("taking_exog", "launch_reglin", "taking_ER")) {
    # avec CA3
    result <- model_fn(
      data = data,
      exogenous = exogenous,
      prediction_period = prediction_period,
      siren_list = siren
    )
  } else {
    # sans CA3
    result <- model_fn(
      data = data,
      prediction_period = prediction_period,
      siren_list = siren
    )
  }
  return(result)
}

safe_launch_model <- purrr::safely(.f = launch_model)


# lancer le pipeline --------------------------------------

test <-
  input %>%
  group_by(flux, regdem) %>%
  sample_n(size = 40) %>%
  # sample_frac(size = 0.01) %>%
  ungroup() %>%
  semi_join(
    x = input,
    by = join_by(flux, siren)
  )

tictoc::tic()

library(furrr)

plan(strategy = "multisession", workers = availableCores() - 1)

output_test <-
  input %>%
  mutate(
    result = future_pmap(
      .f = safe_launch_model,
      # .progress = TRUE,
      .l = list(
        data = data,
        exogenous = exogenous,
        prediction_period = prediction_period,
        siren = siren,
        model = model
      )
    )
  ) %>%
  mutate(
    error = map(.x = result, .f = ~ .$error),
    result = map(.x = result, .f = ~ .$result)
  )

plan(strategy = "sequential")

saveRDS(object = output_test, file = "JMS/workflow_data.rds")

tictoc::toc()

results_test <-
  output_test %>%
  unnest(cols = c(result), names_repair = "universal") %>%
  select(siren, flux, regdem, prediction_period, model, result) %>%
  inner_join(
    x = endogenous,
    by = join_by(
      siren, regdem, flux,
      period == prediction_period
    )
  )

# Comparer aux vraies valeurs ---------------------------------------------
results_test %>%
  mutate(echec_modele = is.na(result)) %>%
  count(model, flux, regdem, echec_modele) %>%
  spread(echec_modele, n, fill = 0) %>%
  janitor::adorn_percentages() %>%
  janitor::adorn_pct_formatting(affix_sign = TRUE)

results_test %>%
  summarise(
    cor = cor(x = result, y = vart, use = "pairwise.complete.obs"),
    .by = c(model, flux, regdem)
  ) %>%
  arrange(-cor) %>%
  group_split(flux, regdem)

results_test %>%
  ggplot(mapping = aes(x = vart, y = result, colour = model)) +
  geom_point() +
  geom_abline() +
  # geom_smooth(method = "lm") +
  scale_x_log10() +
  scale_y_log10() +
  facet_grid(
    cols = vars(flux, regdem),
    rows = vars(model), scales = "free"
  )
lims(
  x = c(0, 8e5),
  y = c(0, 8e5)
)
