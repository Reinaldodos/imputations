

### Create introduction object

introduction <- NR(
  endogenous = endogenous_intro,
  endo_name = "vart",
  flow = "I",
  exogenous = exogenous_intro,
  exog_name = "medoc_0031"
)


### Launch simulations

source(file = "Refactoring/Fonctions/launch_estimation.R")

intro_imput <- launch_all_estimations(
  flow_name = "intro",
  dates = date_prediction,
  sample = sample_intro,
  output_directory = output_directory,
  learning_from = learning_from,
  nb_years_regressions = nb_years_regressions
)


### Launch distributions

intro_ventil <- launch_all_distributions(
  object = introduction,
  input = input_object,
  imput_result = intro_imput,
  dates = date_prediction,
  detail_data = detail_intro
)


### Add previous months

intro_imput_with_past_month <- add_historical_simulation(introduction, input_object, intro_imput, type = "imput")

intro_ventil_with_past_month <- add_historical_simulation(introduction, input_object, intro_ventil, type = "ventil")


### Add gazelec file

intro_imput_with_gazelec <- add_gazelec(
  introduction,
  input_object,
  intro_imput_with_past_month,
  type = "imput",
  pass_names = pass_names
)

intro_ventil_with_gazelec <- add_gazelec(
  introduction,
  input_object,
  intro_ventil_with_past_month,
  type = "ventil",
  pass_names = pass_names
)


### Skip MSD

intro_imput_rect <- remove_msd(
  object = introduction,
  msd = msd,
  result = intro_imput_with_gazelec,
  type = "imput",
  input = input_object
)
date_prediction %>%
  map( ~ export_imput_to_csv(
    data = intro_imput_rect,
    date = .x,
    filename_format = file.path(
      output_directory,
      sprintf(imput_filename_format, "intro", "%s")
    )
  ))
# date_prediction %>%
#   map(~export_imput_to_csv(
#     data = intro_imput_rect, date = .x,
#     filename_format = file.path(output_freenas_directory,
#                                 sprintf(imput_filename_format, "intro", "%s"))
#   ))

intro_ventil_rect <- remove_msd(
  object = introduction,
  msd = msd,
  result = intro_ventil_with_gazelec,
  type = "ventil",
  input = input_object
)
export_ventil_to_csv(intro_ventil_rect,
                     filename = file.path(output_directory,
                                          sprintf(ventil_filename_format, "intro")))
# export_ventil_to_csv(intro_ventil_rect,
#                      filename = file.path(output_freenas_directory,
#                                           sprintf(ventil_filename_format, "intro")))

# historical_basis <- export_to_historical_basis(input_object, intro_ventil_rect,
#                                                "intro", save = T)

remove(
  introduction,
  endogenous_intro,
  detail_intro,
  exogenous_intro,
  intro_imput,
  intro_ventil,
  intro_imput_with_past_month,
  intro_ventil_with_past_month,
  intro_imput_with_gazelec,
  intro_ventil_with_gazelec,
  intro_imput_rect
)
