MSD_from_DebAdmin <- function(data, debadmin) {
  if (debadmin) {
    colnames(data) <- colnames(data)[2:ncol(data)]
    data <- data[, -ncol(data)]
  }
  return(data)
}

import_msd <- function(data) {
  data %>%
    rowwise() %>%
    mutate(data = list(
      rio::import(
        file = file.path(directory, files),
        na.strings = "",
        row.names = NULL,
        skip = skiprows,
        encoding = encoding,
        colClasses = c(siret = "character")
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
    unnest(cols = c(data)) %>%
    filter(Statut == "Actif") %>%
    group_by(siren, Flux) %>%
    reframe(period = unique(period)) %>%
    mutate(flux = Flux %>%
      str_sub(end = 1)) %>%
    return()
}
