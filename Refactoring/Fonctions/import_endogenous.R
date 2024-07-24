import_endogenous <- function(object, flow) {
  flow_dict <- data.frame(
    flow = c("E", "I"),
    flow_name = c("exped", "intro"),
    variable = c("regdem", NA)
  )
  flow_name <- flow_dict[flow_dict$flow == flow, ]$flow_name
  filename <- sprintf("endogenous_%s.rds", flow_name)
  variable <- na.omit(c(
    "siren_new", "period",
    flow_dict[flow_dict$flow == flow, ]$variable
  ))
  
  if (!file.exists(file.path(input_directory, filename))) {
    delete_data <- import_delete(object = object)
    
    sample <-
      import_sample(
        input_directory = input_directory,
        sample = sample_file
      ) %>%
      get_sample_by_flow(flow = flow)
    
    
    if (use_historical_basis) {
      # Read previous input
      historical_imput_data <- readRDS(
        file.path(historical_directory, filename)
      ) %>%
        subset(
          subset = (
            (period >= (date_ref - years(11))) &
              (period <= (date_ref - years(3) - months(1)))
          )
        )
      
      # Read current file
      source_file <- slot(
        object = object,
        name = sprintf("%s_imput", flow_name)
      )
      current_imput_data <- data_treatment(
        source_file,
        source_file[source_file$historical == F, ]$files,
        rename_list = c("siren" = "sire"),
        total_variable = "sire"
      )
      imput_data <- bind_rows(historical_imput_data, current_imput_data)
    } else {
      source_file <- slot(
        object = object,
        name = sprintf("%s_imput", flow_name)
      )
      imput_data <- source_file$files %>%
        map_df(
          ~ data_treatment(source_file, .x,
                           total_variable = "sire",
                           rename_list = c("siren" = "sire")
          )
        ) %>%
        bind_rows()
    }
    
    imput_data <- left_join(
      imput_data, delete_data,
      by = "siren"
    ) %>%
      rowwise() %>%
      mutate(
        siren_new = ifelse(test = is.na(siren_repreneur),
                           yes = siren,
                           no = siren_repreneur
        ),
        vart_new = ifelse(test = is.na(ratio),
                          yes = vart,
                          no = vart * ratio
        )
      ) %>%
      ungroup() %>%
      group_by_at(variable) %>%
      summarise(vart = sum(vart_new)) %>%
      ungroup() %>%
      rename("siren" = "siren_new")
    # sirens_extra <- sample[sample %notin% unique(imput_data$siren)]
    sirens_extra <- subset(sample,
                           subset = (siren %notin% imput_data$siren),
                           select = siren
    ) %>%
      unique() %>%
      flatten_chr()
    if (flow == "I") {
      imput_data <- bind_rows(
        imput_data,
        data.frame(
          siren = sirens_extra,
          period = date_ref,
          vart = NA
        )
      )
    } else {
      imput_data <- bind_rows(
        imput_data,
        data.frame(
          siren = rep(sirens_extra, 2),
          period = date_ref,
          regdem = rep(c("21", "29"), each = length(sirens_extra)),
          vart = NA
        )
      )
      imput_data <- pivot_wider(
        imput_data,
        names_from = regdem,
        values_from = vart,
        names_prefix = "vart_",
        values_fill = 0
      )
    }
    saveRDS(
      imput_data,
      file.path(input_directory, filename)
    )
  } else {
    imput_data <- readRDS(
      file.path(input_directory, filename)
    )
  }
  
  if (save_historical_input) {
    saveRDS(
      imput_data,
      file.path(
        historical_directory,
        filename
      )
    )
  }
  return(imput_data)
}
