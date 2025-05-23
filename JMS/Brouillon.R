Erreurs <-
  output_test %>%
  mutate(is_error = map(.x = error, .f = is.null)) %>%
  unnest(cols = c(is_error))

Erreurs %>%
  count(echec_modele = !is_error, model, flux, regdem) %>%
  spread(echec_modele, n, fill = 0) %>%
  janitor::adorn_percentages() %>%
  janitor::adorn_pct_formatting(affix_sign = TRUE)

Erreurs %>%
  filter(!is_error) %>%
  split(x = .$error, f = paste(.$siren, .$model, sep = " : "))

pluck_pull <- function(string) {
  pluck(.x = test, string, 1)
}
test <-
  output_test %>%
  filter(model == "taking_exog") %>%
  sample_n(1)

taking_exog(
  data = pluck_pull(string = "data"),
  exogenous = pluck_pull(string = "ca3"),
  siren_list = pluck_pull(string = "siren"),
  prediction_period = pluck_pull(string = "prediction_period")
)


sample %>%
  dplyr::count(date_beg) %>%
  filter(date_beg < date_a_predire) %>%
  top_n(n = 1, wt = date_beg) %>%
  semi_join(x = sample)

exogenous %>%
  dplyr::count(flux, period) %>%
  spread(flux, n) %>%
  data.frame()

input %>%
  filter(model == "launch_reglin") %>%
  select(siren, flux, regdem, exogenous)
