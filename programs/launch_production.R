production_object <- Production(
  introduction = intro_ventil_rect, 
  expedition = exped_ventil_rect, 
  pass_table = import_pass_table(input_object, pass_names)
)

eurostatSH2 <- GetEurostatSH2Format(
  object = production_object, 
  filename = file.path(output_directory,
                       sprintf("production_eurostatSH2_ref%s.csv", 
                               format(date_ref, "%Y%m"))),
  exclu = c()
)
eurostatCTCI <- GetEurostatCTCIFormat(
  object = production_object, 
  filename = file.path(output_directory,
                       sprintf("production_eurostatCTCI_ref%s.csv", 
                               format(date_ref, "%Y%m"))),
  exclu = c()
)

national_wo_matmil <- GetNationalFormat(
  object = production_object, 
  filename = file.path(output_directory, 
                       sprintf("production_national_ref%s.csv", 
                               format(date_ref, "%Y%m"))), 
  exclu = c(), 
  matmil = F
)

national_matmil <- GetNationalFormat(
  object = production_object, 
  filename = file.path(output_directory, 
                       sprintf("production_national_matmil_ref%s.csv", 
                               format(date_ref, "%Y%m"))), 
  exclu = c(), 
  matmil = T
)
