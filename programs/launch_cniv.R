# au cas o? il faut relancer les programmes cniv a posteriori
intro_ventil_rect <- readRDS(paste0(input_object@output_directory,"/intro_ventil_rect.rds"))
exped_ventil_rect <- readRDS(paste0(input_object@output_directory,"/exped_ventil_rect.rds"))


NR_list <- get_NR_list_from_result(result_intro = intro_ventil_rect, 
                                   result_exped = exped_ventil_rect)

confederation_data <- import_confederation_table(cniv = input_object@cniv)

cniv_data <- data_treatment(source_file = cniv_file, 
                            file = cniv_file[cniv_file$type == "input",]$files, 
                            rename_list = c('siren' = 'sire', 'flow' = 'flux'), 
                            total_variable = 'sire') %>%
  subset(subset = (substr(ngp, 9, 9) != "0")) %>%
  discard(~all(is.na(.))) %>%
  rowwise() %>%
  mutate(type_enquete = if_else(condition = (imex %in% c(1,2)), true = 'DAU', false = 'EMEBI'), 
         vart = sum(vart_i, vart_e), 
         usup = sum(usup_i, usup_e)) %>%
  ungroup() %>%
  subset(select = -c(vart_i, vart_e, usup_i, usup_e))

####################################
###          ESTIMATION          ###
####################################

cniv <- CNIV(data = cniv_data[(cniv_data$imex %in% c(3,4)),])
estimation_ngp <- response_median_predict(
  object = cniv, prediction_period = date_publication[date_publication != date_ref], 
  NR_list = NR_list, 
  product_var = "ngp", 
  product_list = "all", f = "all"
)

dir.create(file.path(output_directory, "wine_spirit"), showWarnings = F)
write.csv2(estimation_ngp, 
           file = file.path(output_directory, "wine_spirit",
                            sprintf("estim_ngp_median_ref%s.csv", 
                                    format(date_ref, "%Y%m"))), 
           row.names = F, na = "")

dir.create(file.path(output_freenas_directory, "wine_spirit"), showWarnings = F)
write.csv2(estimation_ngp, 
           file = file.path(output_freenas_directory, "wine_spirit",
                            sprintf("estim_ngp_median_ref%s.csv", 
                                    format(date_ref, "%Y%m"))), 
           row.names = F, na = "")


#####################
### FILE BUILDING ###
#####################

compute_coverage(
  response_data = cniv_data, estimation = estimation_ngp, 
  NR_list = NR_list, output_dates = date_publication[date_publication != date_ref], 
  f = "E", 
  filename = file.path(output_directory, "wine_spirit","EXPORTATIONS_DEB-DAU_CNIV.xlsx")
)
for (confederation in append(get_cniv_client(input_object), 'CNIV')) {
  print(confederation)
  build_ending_file(
    data_file = file.path(output_directory,"wine_spirit", "EXPORTATIONS_DEB-DAU_CNIV.xlsx"),
    wb = xlsx::loadWorkbook(file.path(
      input_object@cniv[input_object@cniv$type == "reference",]$directory,
      input_object@cniv[input_object@cniv$type == "reference",]$files
    )),
    confederation_table = confederation_data,
    confederation = confederation,
    filename_format = sprintf(
      file.path(output_directory, "wine_spirit",
                "EXPORTATIONS_DEB-DAU_%s.xlsx"),
      confederation
    ),
    f = "E"
  )
}  

dir.create(file.path(output_freenas_directory, "wine_spirit"), showWarnings = F)
file.copy(file.path(output_directory, "wine_spirit") %>% list.files(., full.names = T), file.path(output_freenas_directory, "wine_spirit"))
