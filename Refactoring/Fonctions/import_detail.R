
# Sous-fonction pour charger les données de détail
load_detail_data <- function(source_file, condition) {
  source_file$files %>%
    map(
      .f = data_treatment,
      source_file = source_file,
      file = .x,
      rename_list = c("siren" = "sire"),
      total_variable = "sire",
      condition = condition,
      .progress = TRUE
    ) %>%
    bind_rows()
}

# Sous-fonction pour joindre et modifier les données
join_and_modify_data <- function(detail_data, delete_data) {
  inner_join(
    x = detail_data,
    y = delete_data,
    by = "siren"
  ) %>%
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
    )
}

# Sous-fonction pour résumer les données
summarize_data <- function(modified_data) {
  modified_data %>%
    group_by(
      siren_new,
      period,
      a129,
      nc8,
      payp,
      pyod,
      dept,
      regdem,
      temo,
      natr,
      conf
    ) %>%
    summarise(
      vart = sum(vart_new),
      .groups = "drop"
    ) %>%
    rename(siren = siren_new)
}

# Sous-fonction pour fusionner les données modifiées et originales
merge_modified_and_original_data <- function(detail_data, delete_data, summarized_data) {
  detail_data %>%
    anti_join(delete_data, by = "siren") %>%
    bind_rows(summarized_data)
}

# Fonction principale refactorisée
import_detail <- function(source_file, delete_data, condition) {
  detail_data <- load_detail_data(source_file, condition)
  modified_data <- join_and_modify_data(detail_data, delete_data)
  summarized_data <- summarize_data(modified_data)
  result_data <- merge_modified_and_original_data(detail_data, delete_data, summarized_data)
  
  return(result_data)
}
