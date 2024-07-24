
test =
  import_endogenous(
    source_file = intro_imput_file,
    flow = "I",
    sample = sample_intro,
    delete_data = delete,
    historical_directory = historical_directory,
    input_directory = input_directory,
    save_historical_input = save_historical_input
  )

dplyr::setdiff(test, endogenous_intro)
dplyr::setdiff(endogenous_intro, test)