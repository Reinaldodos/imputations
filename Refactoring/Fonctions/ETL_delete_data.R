
transform_delete_data <- function(data) {
  data %>%
    mutate(
      siren_repreneur =
        tva_repreneur %>%
        str_remove_all(pattern = " ") %>%
        str_sub(start = -9)
    ) %>%
    group_by(siren) %>%
    mutate(n_repreneur = n_distinct(siren_repreneur)) %>%
    ungroup() %>%
    mutate(ratio = 1 / n_repreneur) %>%
    select(siren, siren_repreneur, ratio) %>%
    return()
}

diff_historique_delete_data <- function(data, historique) {
  anti_join(
    x = historique,
    y = data,
    by = join_by(siren)
  ) %>%
    bind_rows(data) %>%
    return()
}

write_delete_data <- function(data, chemin_historique, chemin_ETL) {
  saveRDS(
    object = data,
    file = chemin_historique
  )
  
  arrow::write_feather(
    x = data,
    sink = chemin_ETL
  )
}

transform_diff_delete_data <- function(new_deletions, historique) {
  new_deletions %>%
    transform_delete_data() %>%
    diff_historique_delete_data(historique = historique) %>%
    return()
}


ETL_delete_data <- function(sample_file,
                            chemin_historique,
                            ETL_directory) {
  chemin_new_deletions <-
    sample_file$directory %>%
    last() %>%
    file.path(
      .,
      "removing_list.rds"
    )
  
  list(
    "new_deletions" = chemin_new_deletions,
    "historique" = chemin_historique
  ) %>%
    map(.f = rio::import) %>%
    reduce(.f = transform_diff_delete_data) %>%
    write_delete_data(
      chemin_historique = chemin_historique,
      chemin_ETL = file.path(
        ETL_directory,
        "delete_data.arrow"
      )
    )
}

