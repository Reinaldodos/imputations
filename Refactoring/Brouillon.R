
import_detail = function(source_file, delete_data, condition) {
  detail_data <- source_file$files %>%
    map(
      .f = data_treatment,
      source_file = source_file,
      file = .x,
      rename_list = c('siren' = 'sire'),
      total_variable = "sire",
      condition = condition,
      .progress = TRUE
    ) %>%
    bind_rows()
  
  modified_data <-
    inner_join(x = detail_data,
               y = delete_data,
               by = 'siren') %>%
    mutate(
      siren_new = ifelse(
        test = is.na(siren_repreneur),
        yes = siren,
        no = siren_repreneur
      ),
      vart_new = ifelse(
        test = is.na(ratio),
        yes = vart,
        no = vart * ratio
      )
    ) %>%
    group_by(siren_new,
             period,
             a129,
             nc8,
             payp,
             pyod,
             dept,
             regdem,
             temo,
             natr,
             conf) %>%
    summarise(vart = sum(vart_new),
              .groups = "drop") %>%
    rename('siren' = 'siren_new')
  
  detail_data <-
    detail_data %>%
    anti_join(delete_data, by = 'siren') %>%
    bind_rows(modified_data)
  
  return(detail_data)
}