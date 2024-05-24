import_clean_tibble <- function(file,
                                na.strings = "",
                                encoding = "UTF-8",
                                ...) {
  rio::import(file = file, ...) %>%
    janitor::clean_names() %>%
    tibble::as_tibble() %>%
    return()
}

transform_sample <- function(data) {
  data %>%
    distinct(
      annee,
      mois,
      numtva,
      siret,
      qualite,
      deb_intro,
      deb_expe,
      type_flux,
      etranger,
      centre_stat_rattachement
    ) %>%
    mutate(siren = numtva %>%
             str_sub(start = -9)) %>%
    return()
}

import_samples_transform <- function(sample_file, ...) {
  sample_file %>%
    mutate(chemin = file.path(directory,
                              files)) %>%
    rowwise() %>%
    mutate(data = list(chemin %>%
                         import_clean_tibble(...) %>%
                         transform_sample())) %>%
    select(date_beg, data) %>%
    unnest(cols = c(data)) %>%
    return()
}


# import delete_data ------------------------------------------------------

transform_delete_data <- function(data) {
  data %>%
    mutate(siren_repreneur =
             tva_repreneur %>%
             str_remove_all(pattern = " ") %>%
             str_sub(start = -9)) %>%
    group_by(siren) %>%
    mutate(n_repreneur = n_distinct(siren_repreneur)) %>%
    ungroup() %>%
    mutate(ratio = 1 / n_repreneur) %>%
    select(siren, siren_repreneur, ratio) %>%
    return()
}

diff_historique_delete_data <- function(data, historique) {
  anti_join(x = historique,
            y = data,
            by = join_by(siren)) %>%
    bind_rows(data) %>%
    return()
}

write_delete_data <- function(data, chemin_historique, chemin_ETL) {
  saveRDS(object = data,
          file = chemin_historique)
  
  arrow::write_feather(x = data,
                       sink = chemin_ETL)
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
  chemin_new_deletions =
    sample_file$directory %>%
    last() %>%
    file.path(.,
              "removing_list.rds")
  
  list("new_deletions" = chemin_new_deletions,
       "historique" = chemin_historique) %>%
    map(.f = rio::import) %>%
    reduce(.f = transform_diff_delete_data) %>%
    write_delete_data(
      chemin_historique = chemin_historique,
      chemin_ETL = file.path(ETL_directory,
                             "delete_data.arrow")
    )
}

# import MSD --------------------------------------------------------------

MSD_from_DebAdmin <- function(data, debadmin) {
  if (debadmin) {
    colnames(data) <- colnames(data)[2:ncol(data)]
    data <- data[,-ncol(data)]
    
  }
  return(data)
}

import_msd <- function(data) {
  data %>%
    rowwise() %>%
    mutate(data  = list(
      rio::import(
        file = file.path(directory, files),
        na.strings = "",
        row.names = NULL,
        skip = skiprows,
        encoding = encoding
      ) %>%
        MSD_from_DebAdmin(debadmin = debadmin) %>%
        mutate(
          siren = str_sub(
            string = TVA,
            start = -9,
            end = -1
          ),
          period = make_date(
            year = as.integer(`Année`),
            month = as.integer(Mois),
            day = 1
          )
        )
    )) %>%
    select(data) %>%
    unnest(cols = c(data)) %>%
    group_by(siren, Flux) %>%
    reframe(period = unique(period)) %>% 
    return()
}

import_ca3 = function(base_CA3, sample_intro, delete_data) {
  ca3_data <- 
    base_CA3 %>% 
    connect_to_last_ca3() %>% 
    select(SIREN, PERIODE, Medoc_0031) %>% 
    collect() %>% 
    janitor::clean_names() 
  
  
  ca3_data %>% 
    mutate(period = make_date(year = as.integer(substr(periode, 1, 4)),
                              month = as.integer(substr(periode, 5, 6)),
                              day = 1)) %>%
    subset(subset = ((period >= (min(object@date_prediction) - years(5))) &
                       ((siren %in% sample_intro$siren) |
                          (siren %in% delete_data$siren)))) %>% 
    left_join(y = delete_data, 
              by = 'siren',
              relationship = "many-to-many")  %>% 
    mutate(siren_new = ifelse(test = is.na(siren_repreneur),
                              yes = siren,
                              no = siren_repreneur),
           medoc_0031 = ifelse(test = is.na(ratio),
                               yes = as.numeric(medoc_0031),
                               no = as.numeric(medoc_0031) * ratio)) %>% 
    group_by(siren_new, period) %>%
    summarise(medoc_0031 = sum(medoc_0031),
              .groups = "drop") %>%
    rename('siren' = 'siren_new') %>% 
    return()
 
}