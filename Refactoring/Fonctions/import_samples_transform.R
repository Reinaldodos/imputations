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
    mutate(chemin = file.path(
      directory,
      files
    )) %>%
    rowwise() %>%
    mutate(data = list(chemin %>%
                         import_clean_tibble(...) %>%
                         transform_sample())) %>%
    select(date_beg, data) %>%
    unnest(cols = c(data)) %>%
    return()
}
