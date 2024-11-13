
### Create expedition objects

source(file = "programs/NR.R",
       encoding = "UTF-8")

expedition_29 <- NR(
  # endogenous = endogenous_exped[,c('siren', 'period', 'vart_29')],
  endogenous = endogenous_exped,
  flow = "E", reg_exped = 29, exogenous = NULL, endo_name = "vart_29"
)

expedition_21 <- NR(
  # endogenous = endogenous_exped[,c('siren', 'period', 'vart_21')], 
  endogenous = endogenous_exped,
  flow = "E", reg_exped = 21, endo_name = "vart_21",
  exogenous = ER, exog_name = "vfte",
  ER = ER, ER_name = "vfte"
)


### Launch simulations

exped_imput_29 <- launch_all_estimations(
  object = expedition_29, dates = date_prediction, sample = sample_exped, 
  input = input_object, learning_from = learning_from, 
  nb_years_regressions = nb_years_regressions
)
exped_imput_21 <- launch_all_estimations(
  object = expedition_21, dates = date_prediction, sample = sample_exped, 
  input = input_object, learning_from = learning_from, 
  nb_years_regressions = nb_years_regressions
)
exped_imput <- full_join(
  exped_imput_29, 
  exped_imput_21, 
  by = c('siren', 'period'), 
  suffix = c('_29', '_21')
) %>%
  rowwise() %>%
  mutate(
    prediction = sum(prediction_21, prediction_29), 
    method = ifelse(is.na(method_21), method_29, method_21), 
    method_ref = ifelse(is.na(method_ref_21), method_ref_29, method_ref_21)
  ) %>%
  select(siren, period, method, method_ref, prediction)

### Launch distributions

exped_ventil <- launch_all_distributions(
  object = expedition_21, input = input_object, 
  imput_result = exped_imput, 
  dates = date_prediction, 
  detail_data = rename(detail_exped, "vart_21" = "vart")
)


### Add previous months

exped_imput_with_past_month <- add_historical_simulation(
  expedition_21, input_object, exped_imput, type = "imput"
)

exped_ventil_with_past_month <- add_historical_simulation(
  expedition_21, input_object, exped_ventil, type = "ventil"
)


### Add gazelec file

exped_imput_with_gazelec <- add_gazelec(
  expedition_21, input_object, exped_imput_with_past_month, type = "imput", 
  by_regdem = F, pass_names = pass_names
)

exped_imput_29_with_gazelec <- add_gazelec(
  expedition_29, input_object, exped_imput_29, type = "imput", by_regdem = T, 
  pass_names = pass_names
)

exped_ventil_with_gazelec <- add_gazelec(
  expedition_21, input_object, exped_ventil_with_past_month, type = "ventil", 
  by_regdem = F, pass_names = pass_names
)


### Skip MSD

exped_imput_rect <- remove_msd(
  object = expedition_21, msd = msd, result = exped_imput_with_gazelec, 
  type = "imput", by_regdem = F, input = input_object
)
date_prediction %>%
  map(~export_imput_to_csv(
    data = exped_imput_rect, date = .x, 
    filename_format = file.path(output_directory, 
                                sprintf(imput_filename_format, "exped", "%s"))
  ))
# date_prediction %>%
#   map(~export_imput_to_csv(
#     data = exped_imput_rect, date = .x,
#     filename_format = file.path(output_freenas_directory,
#                                 sprintf(imput_filename_format, "exped", "%s"))
#   ))

exped_imput_21_rect <- remove_msd(
  object = expedition_21, msd = msd, result = exped_imput_21, 
  type = "imput", by_regdem = T, input = input_object
)
date_prediction %>%
  map(~export_imput_to_csv(
    data = exped_imput_21_rect, date = .x, 
    filename_format = file.path(output_directory, 
                                sprintf("estim_exped_21_%s_ref%s.csv", 
                                        "%s", format(date_ref, "%Y%m")))
  ))
# date_prediction %>%
#   map(~export_imput_to_csv(
#     data = exped_imput_21_rect, date = .x,
#     filename_format = file.path(output_freenas_directory,
#                                 sprintf("estim_exped_21_%s_ref%s.csv",
#                                         "%s", format(date_ref, "%Y%m")))
#    ))

exped_imput_29_rect <- remove_msd(
  object = expedition_29, msd = msd, result = exped_imput_29_with_gazelec, 
  type = "imput", by_regdem = T, input = input_object
)
date_prediction %>%
  map(~export_imput_to_csv(
    data = exped_imput_29_rect, date = .x, 
    filename_format = file.path(output_directory, 
                                sprintf("estim_exped_29_%s_ref%s.csv", 
                                        "%s", format(date_ref, "%Y%m")))
  ))
# date_prediction %>%
#   map(~export_imput_to_csv(
#     data = exped_imput_21_rect, date = .x,
#     filename_format = file.path(output_freenas_directory,
#                                 sprintf("estim_exped_29_%s_ref%s.csv",
#                                         "%s", format(date_ref, "%Y%m")))
#    ))


exped_ventil_rect <- remove_msd(
  object = expedition_21, msd = msd, result = exped_ventil_with_gazelec, 
  type = "ventil", input = input_object
)
export_ventil_to_csv(exped_ventil_rect, 
                     filename = file.path(output_directory, 
                                          sprintf(ventil_filename_format, "exped")))
# export_ventil_to_csv(exped_ventil_rect,
#                      filename = file.path(output_freenas_directory,
#                                           sprintf(ventil_filename_format, "exped")))
# 
# historical_basis <- export_to_historical_basis(input_object, exped_ventil_rect, 
#                                                "exped", save = T)

remove(expedition_21, expedition_29, endogenous_exped, detail_exped, 
       exped_imput_29, exped_imput_21, exped_ventil, ER,
       exped_imput_with_past_month, exped_ventil_with_past_month, 
       exped_imput_with_gazelec, exped_ventil_with_gazelec, exped_imput_rect)
