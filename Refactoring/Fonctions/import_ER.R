
# Fonction pour traiter les mutations des colonnes siren et vfte
mutate_siren_vfte <- function(data) {
  data %>%
    mutate(
      siren_new = if_else(
        condition = is.na(siren_repreneur),
        true = siren,
        false = siren_repreneur
      ),
      vfte = if_else(
        condition = is.na(ratio),
        true = vfte,
        false = vfte * ratio
      )
    )
}

# Fonction pour grouper et sommer les données
group_and_summarise_vfte <- function(data) {
  data %>%
    group_by(siren_new, period) %>%
    summarise(vfte = sum(vfte), .groups = "drop")
}

# Fonction pour renommer la colonne siren_new en siren
rename_siren_new <- function(data) {
  data %>%
    rename(siren = siren_new)
}

# Fonction principale
import_ER <- function(ER_file, delete_data) {
  ER_file %>%
    data_treatment(
      file = ER_file$files,
      total_variable = "sire",
      rename_list = c("siren" = "sire"),
      "regdem == '21'"
    ) %>%
    left_join(y = delete_data, by = join_by(siren)) %>%
    mutate_siren_vfte() %>%
    group_and_summarise_vfte() %>%
    rename_siren_new()
}
