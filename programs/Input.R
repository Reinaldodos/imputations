library(tidyverse)
library(lubridate)
library(rio)
library(janitor)
library(stringr)

Classes <- c(
  siren = "character", sire = "character", SIRE = "character",
  siret = "character",
  SIREN = "character", PERIODE = "character",
  adep = "integer", ADEP = "integer",
  AN = "integer",
  mdep = "integer", MDEP = "integer",
  MOIS = "integer",
  X = "NULL", x = "NULL",
  FLUX = "character",
  period = "Date", period_last = "Date",
  nc8 = "character", NC8 = "character",
  ngp = "character", NGP = "character",
  regdem = "character", REGDEM = "character",
  natr = "character", NATR = "character",
  temo = "character", TEMO = "character",
  dept = "character", DEPT = "character",
  departement = "character",
  region = "character",
  dist_prediction = "double",
  prediction = "double",
  payp = "character", PAYP = "character",
  pyod = "character", PYOD = "character",
  `VFTE - I` = "double", `VFTE - E` = "double",
  vfte = "double", VFTE = "double",
  `VART - I` = "double", `VART - E` = "double",
  vart = "double", VART = "double",
  quan = "double", QUAN = "double",
  `USUP - I` = "double", `USUP - E` = "double",
  USUP = "double", usup = "double",
  conf = "character", CONF = "character",
  medoc_0031 = "integer", MEDOC_0031 = "integer"
)

setClassUnion("tbl_null", c("tbl", "data.frame", "NULL"))
setClassUnion("character_null", c("character", "NULL"))
setClassUnion("date_null", c("Date", "NULL"))
setClassUnion("numeric_null", c("numeric", "NULL"))
setClassUnion("logical_null", c("logical", "NULL"))

`%notin%` <- Negate(`%in%`)

source("programs/MSDtreatment.R", encoding = "UTF-8")
Input <- setClass(
  "Input",

  # Define fields ----
  slots = c(
    date_ref = "date_null",
    date_prediction = "date_null",
    date_publication = "date_null",
    input_directory = "character_null",
    output_directory = "character_null",
    output_freenas_directory = "character_null",
    sample_directory = "character_null",
    historical_directory = "character_null",
    sample = "tbl_null",
    msd = "tbl_null",
    intro_imput = "tbl_null",
    exped_imput = "tbl_null",
    use_historical_basis = "logical",
    save_historical_input = "logical",
    use_gazelec_file = "logical",
    add_gazelec_data = "logical",
    intro_ventil = "tbl_null",
    exped_ventil = "tbl_null",
    ER = "tbl_null",
    ca3 = "tbl_null",
    gazelec = "tbl_null",
    pass = "tbl_null",
    cniv = "tbl_null",
    atos = "tbl_null"
  ),


  # Default values ----------------------------------------------------------

  prototype = list(
    date_ref = make_date(
      year = year(Sys.Date() - months(1)),
      month = month(Sys.Date() - months(1)),
      day = 1
    ),
    input_directory = "input",
    use_historical_basis = T
  )
)


# FUNCTIONS ---------------------------------------------------------------


get_last_ca3 <- function(base_CA3) {
  list.dirs(path = base_CA3) %>%
    dplyr::as_tibble() %>%
    tidyr::extract(
      col = value,
      into = "mois_envoi",
      regex = "mois_envoi=(.*)",
      convert = TRUE
    ) %>%
    dplyr::filter(mois_envoi == max(mois_envoi, na.rm = TRUE)) %>%
    dplyr::pull(mois_envoi) %>%
    return()
}

connect_to_last_ca3 <- function(base_CA3) {
  derniers_CA3 <- get_last_ca3(base_CA3 = base_CA3)

  chemin <- file.path(
    base_CA3,
    paste0("mois_envoi=", derniers_CA3),
    "donnees_mensuelles.parquet"
  )

  chemin %>%
    arrow::open_dataset() %>%
    return()
}


get_last_histo <- function(base_historique) {
  list.dirs(path = base_historique) %>%
    dplyr::as_tibble() %>%
    tidyr::extract(
      col = value,
      into = "mois_ref",
      regex = "mois_ref=(.*)",
      convert = TRUE
    ) %>%
    dplyr::filter(mois_ref == max(mois_ref, na.rm = TRUE)) %>%
    dplyr::pull(mois_ref) %>%
    return()
}



connect_to_last_histo <- function(base_historique) {
  derniers_simul <- get_last_histo(base_historique = base_historique)

  base_historique %>%
    arrow::open_dataset() %>%
    dplyr::filter(mois_ref == derniers_simul) %>%
    return()
}



import_historique <- function(base_historique) {
  base_historique %>%
    connect_to_last_histo() %>%
    collect() %>%
    clean_names() %>%
    return()
}



import_input <- function(source_file, file, ...) {
  fichier <- rio::import(
    file.path(source_file[source_file$files == file, ]$directory, file),
    colClasses = Classes,
    na.strings = "",
    skip = source_file[source_file$files == file, ]$skiprows,
    encoding = source_file[source_file$files == file, ]$encoding,
    dec = source_file[source_file$files == file, ]$dec,
    ...
  ) %>%
    clean_names() %>%
    as_tibble()
  return(fichier)
}

data_treatment <- function(source_file, file, rename_list, total_variable, ...) {
  condition <- sprintf(
    "(period >= '%s') & (period <= '%s')",
    format(source_file[source_file$files == file, ]$start, "%Y-%m-%d"),
    format(source_file[source_file$files == file, ]$end, "%Y-%m-%d")
  )
  if (source_file[source_file$files == file, ]$astrineo_input) {
    condition <- c(
      sprintf("%s != 'Total Général'", total_variable),
      condition,
      ...
    )
  }
  towards_data <- import_input(
    source_file = source_file,
    file = file
  ) %>%
    mutate(period = make_date(year = adep, month = mdep, day = 1)) %>%
    filter_(.dots = condition) %>%
    rename(all_of(rename_list))
  return(towards_data)
}




# Import sample and delete files ------------------------------------------

import_sample <- function(input_directory, sample) {
  input_path <- file.path(
    input_directory,
    "echantillon.rds"
  )

  if (!file.exists(input_path)) {
    sample <-
      sample$date_beg %>%
      map(
        .f = ~ import_input(sample,
          sample[sample$date_beg == .x, ]$files,
          colClasses = Classes
        ) %>%
          mutate(
            date_beg = .x,
            siren = str_sub(
              string = numtva,
              start = -9,
              end = -1
            )
          ) %>%
          distinct(
            siren,
            annee,
            mois,
            numtva,
            siret,
            qualite,
            deb_intro,
            deb_expe,
            type_flux,
            etranger,
            centre_stat_rattachement,
            date_beg
          )
      ) %>%
      bind_rows()

    saveRDS(
      object = sample,
      file = input_path
    )
  } else {
    sample <- readRDS(file = input_path)
  }

  return(sample)
}

get_sample_by_flow <- function(sample, flow) {
  flow_dict <- data.frame(
    flow = c("E", "I"),
    variable = c("deb_expe", "deb_intro")
  )

  sample %>%
    filter(rlang::UQ(rlang::sym(flow_dict[flow_dict$flow == flow, ]$variable)) == 1) %>%
    distinct(siren, date_beg) %>%
    return()
}

setGeneric(
  name = "import_delete",
  def = function(object, pattern = "suppressions") {
    standardGeneric("import_delete")
  }
)
setMethod(
  f = "import_delete",
  signature = "Input",
  definition = function(object, pattern = "suppressions") {
    if (!file.exists(file.path(object@input_directory, "delete.rds"))) {
      delete_data_initial <- readRDS(file.path(object@historical_directory, "delete.rds"))
      delete_data <- readRDS(file.path(
        last(object@sample$directory),
        "removing_list.rds"
      )) %>%
        mutate(siren_repreneur = str_sub(str_replace_all(tva_repreneur, pattern = " ", replacement = ""), -9, -1)) %>%
        group_by(siren) %>%
        mutate(n_repreneur = n_distinct(siren_repreneur)) %>%
        ungroup() %>%
        mutate(ratio = 1 / n_repreneur) %>%
        select(siren, siren_repreneur, ratio)

      delete_data <- bind_rows(
        anti_join(delete_data_initial,
          delete_data,
          by = "siren"
        ),
        delete_data
      )
      saveRDS(
        delete_data,
        file.path(object@historical_directory, "delete.rds")
      )

      saveRDS(delete_data, file.path(object@input_directory, "delete.rds"))
    } else {
      delete_data <- readRDS(file.path(object@input_directory, "delete.rds"))
    }
    return(delete_data)
  }
)


# ===============================================================================
# Import endogenous
# ===============================================================================

setGeneric(
  name = "import_endogenous",
  def = function(object, flow) {
    standardGeneric("import_endogenous")
  }
)
setMethod(
  f = "import_endogenous",
  signature = "Input",
  definition = function(object, flow) {
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
    if (!file.exists(file.path(object@input_directory, filename))) {
      delete_data <- import_delete(object = object)

      sample <-
        import_sample(
          input_directory = object@input_directory,
          sample = object@sample
        ) %>%
        get_sample_by_flow(flow = flow)


      if (object@use_historical_basis) {
        # Read previous input
        historical_imput_data <- readRDS(
          file.path(object@historical_directory, filename)
        ) %>%
          subset(
            subset = (
              (period >= (object@date_ref - years(11))) &
                (period <= (object@date_ref - years(3) - months(1)))
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
        summarise(
          vart = sum(vart_new),
          .groups = "drop"
        ) %>%
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
            period = object@date_ref,
            vart = NA
          )
        )
      } else {
        imput_data <- bind_rows(
          imput_data,
          data.frame(
            siren = rep(sirens_extra, 2),
            period = object@date_ref,
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
        file.path(object@input_directory, filename)
      )
    } else {
      imput_data <- readRDS(
        file.path(object@input_directory, filename)
      )
    }

    if (object@save_historical_input) {
      saveRDS(
        imput_data,
        file.path(
          object@historical_directory,
          filename
        )
      )
    }
    return(imput_data)
  }
)


# ===============================================================================
# Import ventil
# ===============================================================================

setGeneric(
  name = "import_detail",
  def = function(object, flow, condition) {
    standardGeneric("import_detail")
  }
)
setMethod(
  f = "import_detail",
  signature = "Input",
  definition = function(object, flow, condition) {
    flow_dict <- data.frame(
      flow = c("E", "I"),
      flow_name = c("exped", "intro")
    )
    flow_name <- flow_dict[flow_dict$flow == flow, ]$flow_name
    filename <- sprintf("detail_%s.rds", flow_name)
    if (!file.exists(file.path(object@input_directory, filename))) {
      delete_data <- import_delete(object = object)
      source_file <- slot(
        object,
        sprintf("%s_ventil", flow_name)
      )
      detail_data <- source_file$files %>%
        map_df(
          ~ data_treatment(
            source_file = source_file,
            file = .x,
            rename_list = c("siren" = "sire"),
            total_variable = "sire",
            condition
          )
        ) %>%
        bind_rows()
      modified_data <- inner_join(
        detail_data,
        delete_data,
        by = "siren"
      ) %>%
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
        group_by(
          siren_new, period, a129, nc8, payp, pyod,
          dept, regdem, temo, natr, conf
        ) %>%
        summarise(
          vart = sum(vart_new),
          .groups = "drop"
        ) %>%
        rename("siren" = "siren_new")
      detail_data <- detail_data %>%
        anti_join(delete_data, by = "siren") %>%
        bind_rows(modified_data)
      saveRDS(
        detail_data,
        file.path(object@input_directory, filename)
      )
    } else {
      detail_data <- readRDS(file.path(object@input_directory, filename))
    }
    return(detail_data)
  }
)


# ===============================================================================
# Import CA3
# ===============================================================================

import_ca3 <- function(base_CA3, sample_intro, delete_data, date_prediction) {
  ca3_data <-
    base_CA3 %>%
    connect_to_last_ca3() %>%
    select(SIREN, PERIODE, Medoc_0031) %>%
    collect() %>%
    janitor::clean_names()


  ca3_data %>%
    mutate(period = make_date(
      year = as.integer(substr(periode, 1, 4)),
      month = as.integer(substr(periode, 5, 6)),
      day = 1
    )) %>%
    subset(subset = ((period >= (min(date_prediction) - years(5))) &
      ((siren %in% sample_intro$siren) |
        (siren %in% delete_data$siren)))) %>%
    left_join(
      y = delete_data,
      by = "siren",
      relationship = "many-to-many"
    ) %>%
    mutate(
      siren_new = ifelse(test = is.na(siren_repreneur),
        yes = siren,
        no = siren_repreneur
      ),
      medoc_0031 = ifelse(test = is.na(ratio),
        yes = as.numeric(medoc_0031),
        no = as.numeric(medoc_0031) * ratio
      )
    ) %>%
    group_by(siren_new, period) %>%
    summarise(
      medoc_0031 = sum(medoc_0031),
      .groups = "drop"
    ) %>%
    rename("siren" = "siren_new") %>%
    return()
}

# ===============================================================================
# Import ER
# ===============================================================================

setGeneric(
  name = "import_ER",
  def = function(object) {
    standardGeneric("import_ER")
  }
)
setMethod(
  f = "import_ER",
  signature = "Input",
  definition = function(object) {
    if (!file.exists(file.path(object@input_directory, "ER.rds"))) {
      delete_data <- import_delete(object)
      ER_data <- data_treatment(
        object@ER,
        object@ER$files,
        total_variable = "sire",
        rename_list = c("siren" = "sire"),
        "regdem == '21'"
      ) %>%
        left_join(delete_data, by = "siren") %>%
        mutate(
          siren_new = ifelse(test = is.na(siren_repreneur),
            yes = siren,
            no = siren_repreneur
          ),
          vfte = ifelse(test = is.na(ratio),
            yes = vfte,
            no = vfte * ratio
          )
        ) %>%
        group_by(siren_new, period) %>%
        summarise(
          vfte = sum(vfte),
          .groups = "drop"
        ) %>%
        rename("siren" = "siren_new")
      saveRDS(
        ER_data,
        file.path(object@input_directory, "ER.rds")
      )
    } else {
      ER_data <- readRDS(file.path(object@input_directory, "ER.rds"))
    }
    return(ER_data)
  }
)


# ===============================================================================
# Import historical simulation
# ===============================================================================

setGeneric(
  name = "import_historical_simulation",
  def = function(object, flow, date) {
    standardGeneric("import_historical_simulation")
  }
)
setMethod(
  f = "import_historical_simulation",
  signature = "Input",
  definition = function(object, flow, date) {
    flow_dict <- data.frame(
      flow = c("E", "I"),
      flow_name = c("exped", "intro")
    )
    historical_basis <- import_historique(base_historique) %>%
      mutate(
        period_last = as.Date(period_last),
        period = as.Date(period)
      ) %>%
      filter((mois_ref == format(object@date_ref - months(1), "%Y%m")) &
        (source == "chiffre") &
        (period %in% as_date(date)) &
        (period_last < period) &
        (flux == flow_dict[flow_dict$flow == flow, ]$flow_name)) %>%
      subset(select = c(
        siren, period, prediction, period_last, a129, nc8,
        payp, pyod, dept, regdem, temo, natr, endo, sum_endo,
        ratio, dist_prediction, method, method_ref, conf
      ))
    return(historical_basis)
  }
)


# ===============================================================================
# Import gazelec file
# ===============================================================================

setGeneric(
  name = "import_gazelec",
  def = function(object, flow, pass_names) {
    standardGeneric("import_gazelec")
  }
)
setMethod(
  f = "import_gazelec",
  signature = "Input",
  definition = function(object, flow, pass_names) {
    if (flow %notin% c("I", "E")) {
      stop("'flow' must be 'I' or 'E'.")
    }
    if (flow == "I") {
      group <- c("siren", "period", "flux")
    } else {
      group <- c("siren", "period", "flux", "regdem")
    }
    if (object@use_gazelec_file) {
      pass_table <- import_pass_table(object, pass_names) %>%
        subset(
          subset = (year == year(object@date_ref)),
          select = c(nc8, a129)
        )
      gazelec_data <- import_input(object@gazelec, object@gazelec$files) %>%
        mutate(
          across(
            c(valeur, masse_nette_quantit_u_fffd, unit_s_suppl_u_fffd_mentaires),
            ~ parse_number(.x, locale = locale(decimal_mark = ","))
          )
        ) %>%
        mutate(
          period = make_date(year = ann_e, month = mois, day = 1),
          n_tva = str_replace_all(n_tva_du_redevable, " ", ""),
          siren = str_sub(n_tva_du_redevable, -9, -1),
          regdem = str_sub(as.character(r_gime), 1, 2),
          flux = ifelse(test = (str_sub(as.character(r_gime), 1, 1) == "1"),
            yes = "I",
            no = "E"
          ),
          dist_prediction = as.numeric(as.character(valeur)),
          method = "reglementation",
          method_ref = "reglementation",
          period_last = NA, payp = pays_de_provenance,
          pyod = pays_de_destination, conf = NA,
          endo = NA, sum_endo = NA, ratio = NA,
          temo = as.character(mode_de_transport),
          natr = as.character(nature_transaction),
          dept = as.character(d_partement),
          nc8 = str_pad(
            string = as.character(nomenclature_nc8),
            width = 8, side = "left", pad = "0"
          )
        ) %>%
        group_by_at(group) %>%
        mutate(prediction = sum(dist_prediction)) %>%
        ungroup() %>%
        subset(
          subset = (flux == flow),
          select = c(
            siren, period, prediction, method, method_ref,
            period_last, nc8, pyod, payp, dept, temo, natr, regdem,
            conf, endo, sum_endo, ratio, dist_prediction
          )
        ) %>%
        left_join(pass_table, by = "nc8") %>%
        mutate(conf = "0")
    } else {
      gazelec_data <- data.frame()
    }
    return(gazelec_data)
  }
)


# ===============================================================================
# Import pass tables
# ===============================================================================

get_pass_table <- function(pass_file, file, pass_names) {
  pass_data <- rio::import(
    file.path(
      pass_file[pass_file$files == file, ]$directory, file
    ),
    range = readxl::cell_cols(pass_file[pass_file$files == file, ]$cols),
    col_names = pass_names
  ) %>%
    as_tibble() %>%
    subset(subset = (annee != "Ann?e")) %>%
    mutate(
      year = as.integer(annee),
      nc8 = substr(ngp9, 1, 9)
    )
  return(pass_data)
}
setGeneric(
  name = "import_pass_table",
  def = function(object, pass_names) {
    standardGeneric("import_pass_table")
  }
)
setMethod(
  f = "import_pass_table",
  signature = "Input",
  definition = function(object, pass_names) {
    pass_data <- object@pass$files %>%
      map_df(~ get_pass_table(
        pass_file = object@pass,
        file = .x,
        pass_names = pass_names
      )) %>%
      bind_rows() %>%
      mutate(nc8 = substr(ngp9, 1, 8)) %>%
      group_by(year, nc8, a129) %>%
      summarise(
        ctci = unique(ctci),
        .groups = "drop"
      )
    return(pass_data)
  }
)


# ===============================================================================
# Import CNIV tables
# ===============================================================================

import_confederation_table <- function(cniv) {
  cniv %>%
    filter(type == "confederation_to_ngp") %>%
    mutate(path = file.path(directory, files)) %>%
    pull(path) %>%
    read.csv2(
      colClasses = "character",
      col.names = c("id_technique", "code_orga", "nc8", "ngp", "appellelation"),
      na.strings = c("", " ")
    ) %>%
    as_tibble() %>%
    filter(nchar(nc8) == 8) %>%
    mutate(ngp = case_when(!is.na(ngp) ~ paste(nc8, ngp, sep = ""))) %>%
    distinct(nc8, ngp, code_orga) %>%
    return()
}


get_cell_value_by_bg_color <- function(cell, exclu_color) {
  color <- xlsx::getCellStyle(cell)$getFillForegroundColorColor()$getHexString()
  if (color != exclu_color) {
    return(xlsx::getCellValue(cell))
  } else {
    return(NULL)
  }
}

setGeneric(
  name = "get_cniv_client",
  def = function(object) {
    standardGeneric("get_cniv_client")
  }
)
setMethod(
  f = "get_cniv_client",
  signature = "Input",
  definition = function(object) {
    workbook <- xlsx::loadWorkbook(
      file.path(
        object@cniv[object@cniv$type == "client", ]$directory,
        object@cniv[object@cniv$type == "client", ]$files
      ),
    )
    sheets <- xlsx::getSheets(workbook)
    sheet_name <- names(sheets)[1]
    clients <- xlsx::getCells(
      xlsx::getRows(sheets[[sheet_name]]),
      colIndex = 3
    ) %>%
      map(~ get_cell_value_by_bg_color(.x, "0:0:0")) %>%
      bind_rows()
    return(clients)
  }
)
