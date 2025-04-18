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


# Mise en forme des inputs ------------------------------------------------
echantillon = 
  sample %>% 
  select(siren, starts_with("deb_")) %>% 
  pivot_longer(cols = starts_with("deb_"),
               names_to = "flux",values_to = "TOTO", names_prefix = "deb_"
  )%>% 
  filter(TOTO == 1) %>%
  select(-TOTO)


endogenous <- 
  list(
    endogenous_intro %>%
      mutate(regdem = "all",
             flux = "intro"),
    endogenous_exped %>%
      pivot_longer(
        cols = starts_with("vart_"),
        names_to = "regdem",
        values_to = "vart",
        names_prefix = "vart_"
      ) %>%
      filter(vart > 0) %>% 
      mutate(flux = "expe")
  ) %>% 
  bind_rows()

exogenous <- 
  list(
    exogenous_intro %>% 
      mutate(flux = "intro"),
    ER %>% 
      mutate(flux = "expe")
  ) %>% 
  bind_rows()
  
# importer les fichiers à utiliser ----------------------------------------



input <-
  list(
    endogenous %>% 
      
      group_nest(siren, flux, regdem, .key = "data", 
                 keep = TRUE),
    exogenous %>%
      group_nest(siren, flux, .key = "ca3", 
                 keep = TRUE),
    modeles
  ) %>%
  reduce(.f = left_join) %>%
  semi_join(y = echantillon,
            by = join_by(siren, flux)) %>% 
  mutate(prediction_period = as_date(max(date_prediction)))


# Construire une factory d'appel dynamique des modèles --------------------

launch_model <- function(model,
                         data,
                         exogenous,
                         prediction_period,
                         siren) {
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

safe_launch_model <- safely(.f = launch_model)


# lancer le pipeline --------------------------------------
test <- 
  input %>% 
  group_by(model, flux, regdem) %>% 
  sample_n(10) %>% 
  ungroup() %>% 
  arrange(siren)
  
output_test <- 
  test %>% 
  mutate(
    result = pmap(.f = safe_launch_model, 
                  .progress = TRUE, 
                  .l = list(data = data,
                            exogenous = ca3,
                            prediction_period = prediction_period,
                            siren = siren,
                            model = model))
  ) %>% 
  mutate(
    error = map(.x = result, .f = ~.$error),
    result = map(.x = result, .f = ~.$result)
  )

results_test <- 
  output_test %>%
  unnest(cols = c(result), names_repair = "universal") %>%
  select(siren, flux, regdem, prediction_period, model, result)


# Comparer aux vraies valeurs ---------------------------------------------

endogenous %>% 
  inner_join(y = results_test,
             by = join_by(siren, regdem, flux,
                          period == prediction_period)) %>% 
  ggplot(mapping = aes(x = vart, y = result, colour = model)) +
  geom_point() +
