# Appel des Packages ----
library(tidyverse)
library(xlsx)
library(openxlsx)
library(lubridate)

# Variables d'environemment ------

## Mois chiffre statistique -----
mstat <- format(date_ref, "%Y-%m-%d")

## Type de production -----
prod <- "Pre-chiffre"

## Chemins ----
### répertoire des données ----
Path_Data <- file.path("data")

### répertoire des output -----
Path_PC <- "output_PC"

### chemin base sirene parquet ----
sirene_directory <- "C:/Users/smethodo/Documents/SIRENE"

# Fichiers de nomenclatures -----

## Tables des codes pays d'origine (monde entier) ----
file_pyod <- "PYOD_partners.xlsx"
list_pyod <- xlsx::read.xlsx(file = file.path(Path_Data, file_pyod), 1)

## Tables des codes pays des E.M de l'UE ----
list_partners <- xlsx::read.xlsx(file = file.path(Path_Data, file_pyod), 2)

##  Table de passage Polyco NC8 - A1329 (2022) mais non utilisée ------
file_NC82022 <- "NC8_22 vers CPF6_A129.csv"
list_nc82022 <- read.csv2(
  file = file.path(Path_Data, file_NC82022),
  sep = ";",
  colClasses = "character"
)

# Chemins complets des fichiers des données d'imputations ---

## Fichier estim_intro ----
filePC_imp_intro <- list.files(Path_PC,
  pattern = paste0(
    "estim_intro_",
    year(ymd(mstat)),
    sprintf(
      "%02d",
      month(ymd(mstat))
    )
  )
) %>%
  str_subset(string = ., pattern = "csv$")

## Fichier .csv estim_iexped_21 ----
filePC_imp_exped21 <- list.files(Path_PC,
  pattern = paste0(
    "estim_exped_21_",
    year(ymd(mstat)),
    sprintf(
      "%02d",
      month(ymd(mstat))
    )
  )
) %>%
  str_subset(string = ., pattern = "csv$")

## Fichier .csv estim_exped_29 ----
filePC_imp_exped29 <- list.files(Path_PC,
  pattern = paste0(
    "estim_exped_29_",
    year(ymd(mstat)),
    sprintf(
      "%02d",
      month(ymd(mstat))
    )
  )
) %>%
  str_subset(string = ., pattern = "csv$")

## Fichier .csv ventil_intro ----
filePC_ventil_intro <- list.files(Path_PC, pattern = "ventil_intro") %>%
  str_subset(string = ., pattern = "csv$")

## Fichier .csv ventil_exped ----
filePC_ventil_exped <- list.files(Path_PC, pattern = "ventil_exped") %>%
  str_subset(string = ., pattern = "csv$")


# Appel des fonctions de contrôle des fichiers ---
source(file = "programs/fonctions_controles_yb.R", encoding = "UTF-8")

# Lecture des fichiers d'imputations non ventilées -----

## imputations non ventilées : Introductions -----
imput_intro <- read.csv2(
  file = file.path(Path_PC, filePC_imp_intro),
  sep = ";",
  colClasses = c(siren = "character")
) %>%
  select(siren, period, prediction, method, method_ref)

## imputations non ventilées : Expéditions régime 21 ----
imput_exped21 <- read.csv2(
  file = file.path(Path_PC, filePC_imp_exped21),
  sep = ";",
  colClasses = c(siren = "character")
) %>%
  select(siren, period, prediction, method, method_ref)

## imputations non ventilées : Expéditions régime 29 ----
imput_exped29 <- read.csv2(
  file = file.path(Path_PC, filePC_imp_exped29),
  sep = ";",
  colClasses = c(siren = "character")
) %>%
  select(siren, period, prediction, method, method_ref)

imput_exped <- bind_rows(imput_exped21, imput_exped29)
imput_exped <- aggregate(prediction ~ siren + period, data = imput_exped, sum)

# Lecture des fichiers d'imputations ventilées -----

## imputations ventilées : Introductions -----
ventil_intro <- read.csv2(
  file = file.path(Path_PC, filePC_ventil_intro),
  sep = ";",
  colClasses = Classes,
  na.strings = ""
) %>%
  filter(!is.na(dist_prediction))

## imputations ventilées : Expéditions -----
ventil_exped <- read.csv2(
  file = file.path(Path_PC, filePC_ventil_exped),
  sep = ";",
  colClasses = Classes,
  na.strings = ""
) %>%
  filter(!is.na(dist_prediction))

ventil_exped21 <- ventil_exped %>% filter(regdem == 21)
ventil_exped29 <- ventil_exped %>% filter(regdem == 29)



# Controles des imputations ----

## Introductions -----
### Récapitulatif des imputations à l'introduction ---
tot_imp_intro <- ctrl_tot_imp(imput_intro)

### Imputation par tranche de valeur ----
split_imp_intro <- ctrl_class_imp(imput_intro)

### Imputation par méthode utilisée ----
meth_imp_intro <- ctrl_method_imp(imput_intro)

tot_imp_exped21 <- ctrl_tot_imp(imput_exped21)
split_imp_exped21 <- ctrl_class_imp(imput_exped21)
meth_imp_exped21 <- ctrl_method_imp(imput_exped21)

## Expéditions -----
### Récapitulatif des imputations à l'expédition (régime 21 et 29) ---
tot_imp_exped29 <- ctrl_tot_imp(imput_exped29)
split_imp_exped29 <- ctrl_class_imp(imput_exped29)
meth_imp_exped29 <- ctrl_method_imp(imput_exped29)

### Imputation par tranche de valeur ----
tot_imp_exped <- ctrl_tot_imp(imput_exped)
split_imp_exped <- ctrl_class_imp(imput_exped)


# Siren avec une imputation de 10 millions ou plus -------

## Extraction liste des siren avec une imputation >= 10 millions -----
list_i_siren10M <- list_seuil_pred(ventil_intro, 10000000) %>% mutate(period = as_date(period))
list_e_siren10M <- list_seuil_pred(ventil_exped, 10000000) %>% mutate(period = as_date(period))

liste_ul_siren10M <- unique(c(list_i_siren10M$siren, list_e_siren10M$siren))

## Appariement des Siren imputés avec le parquet sirene ----
sirene_plus_10M <-
  arrow::open_dataset(
    sources = file.path(sirene_directory, "StockUniteLegale_utf8.parquet")
  ) %>%
  filter(siren %in% liste_ul_siren10M) %>%
  select(
    "siren", "etatAdministratifUniteLegale",
    "denominationUniteLegale", "activitePrincipaleUniteLegale"
  ) %>%
  collect()

### Siren avec une imputation de 10 millions ou plus à l'introduction -----
list_i_siren10M <-
  list_i_siren10M %>%
  left_join(sirene_plus_10M, by = "siren") %>%
  relocate(
    "period", "siren", "denominationUniteLegale",
    "activitePrincipaleUniteLegale", "prediction",
    "etatAdministratifUniteLegale"
  ) %>%
  rename(
    raison.sociale = denominationUniteLegale,
    APE = activitePrincipaleUniteLegale,
    etat = etatAdministratifUniteLegale
  ) %>%
  arrange("period", desc("prediction"))

intro_sample <- sample %>%
  filter(deb_intro == 1) %>%
  distinct(siren, numtva, date_beg) %>%
  arrange(siren, numtva, date_beg) %>%
  distinct(siren, .keep_all = T)

list_i_siren10M <- list_i_siren10M %>% left_join(intro_sample, by = c("siren"))

### Siren avec une imputation de 10 millions ou plus à l'expédition -----
list_e_siren10M <- list_e_siren10M %>%
  left_join(sirene_plus_10M, by = "siren") %>%
  relocate(
    "period", "siren", "denominationUniteLegale",
    "activitePrincipaleUniteLegale", "prediction",
    "etatAdministratifUniteLegale"
  ) %>%
  rename(
    raison.sociale = denominationUniteLegale,
    APE = activitePrincipaleUniteLegale,
    etat = etatAdministratifUniteLegale
  ) %>%
  arrange("period", desc("prediction"))

exped_sample <- sample %>%
  filter(deb_expe == 1) %>%
  distinct(siren, numtva, date_beg) %>%
  arrange(siren, numtva, date_beg) %>%
  distinct(siren, .keep_all = T)

list_e_siren10M <- list_e_siren10M %>% left_join(exped_sample, by = c("siren"))


# Controles des ventilations ---------

## Controles des ventilations à l'introduction -----
siren_ventil_intro <- ctrl_siren_ventil(ventil_intro)
nmctr_ventil_intro <- ctrl_nmctr_ventil(ventil_intro)
imp_ventil_intro <- ctrl_imp_ventil(ventil_intro)

### contrôle spécifique PYOD - Namibie et NA
list_i_pyod <- ventil_intro %>%
  filter(period == mstat) %>%
  distinct(pyod) %>%
  filter(!(pyod %in% list_pyod$CODE))
if (nrow(list_i_pyod) == 0) {
  list_i_pyod[1, 1] <- "Aucune"
}

### contrôle spécifique PAYP - uniquement E.M UE ---
list_i_payp <- ventil_intro %>%
  filter(period == mstat) %>%
  distinct(payp) %>%
  filter(!(payp %in% list_partners$CODE))
if (nrow(list_i_payp) == 0) {
  list_i_payp[1, 1] <- "Aucune"
}

## Controles des ventilations à l'expédition -----
siren_ventil_exped21 <- ctrl_siren_ventil(ventil_exped21)
nmctr_ventil_exped21 <- ctrl_nmctr_ventil(ventil_exped21)
imp_ventil_exped21 <- ctrl_imp_ventil(ventil_exped21)

siren_ventil_exped29 <- ctrl_siren_ventil(ventil_exped29)
nmctr_ventil_exped29 <- ctrl_nmctr_ventil(ventil_exped29)
imp_ventil_exped29 <- ctrl_imp_ventil(ventil_exped29)

siren_ventil_exped <- ctrl_siren_ventil(ventil_exped)
nmctr_ventil_exped <- ctrl_nmctr_ventil(ventil_exped)
imp_ventil_exped <- ctrl_imp_ventil(ventil_exped)

### contrôle spécifique PYOD - Namibie et NA
list_e_pyod <- ventil_exped %>%
  filter(period == mstat) %>%
  distinct(pyod) %>%
  filter(!(pyod %in% list_partners$CODE))
if (nrow(list_e_pyod) == 0) {
  list_e_pyod[1, 1] <- "Aucune"
}

### contrôle spécifique PAYP - uniquement E.M UE ---
list_e_payp <- ventil_exped %>%
  filter(period == mstat) %>%
  distinct(payp) %>%
  filter(!(payp %in% list_pyod$CODE))
if (nrow(list_e_payp) == 0 | (nrow(list_e_payp) == 1 & is.na(list_e_payp[1, 1]))) {
  list_e_payp[1, 1] <- "Aucune"
}


# Tables des résultats -----------

## Résultat des contrôles ------

### Comparaison entre le fichier des imputations et celui des ventilations ----
tab_intro <- tot_imp_intro %>%
  mutate(period = as_date(period)) %>%
  left_join(siren_ventil_intro, by = "period") %>%
  select(period, siren_imp, imputation, siren_ventil) %>%
  left_join(imp_ventil_intro, by = "period") %>%
  select(siren_imp, imputation, siren_ventil, tot_imput) %>%
  rename(imput_ventil = tot_imput) %>%
  mutate(
    flux = "Introductions",
    diff_siren = siren_imp - siren_ventil,
    variation = imput_ventil - imputation,
    evolution = variation / imputation
  ) %>%
  relocate(
    flux, siren_imp, siren_ventil, diff_siren,
    imputation, imput_ventil, variation, evolution
  )


tab_exped <- tot_imp_exped %>%
  mutate(period = as_date(period)) %>%
  left_join(siren_ventil_exped, by = "period") %>%
  select(period, siren_imp, imputation, siren_ventil) %>%
  left_join(imp_ventil_exped, by = "period") %>%
  select(siren_imp, imputation, siren_ventil, tot_imput) %>%
  rename(imput_ventil = tot_imput) %>%
  mutate(
    flux = "Expéditions",
    diff_siren = siren_imp - siren_ventil,
    variation = imput_ventil - imputation,
    evolution = variation / imputation
  ) %>%
  relocate(
    flux, siren_imp, siren_ventil, diff_siren,
    imputation, imput_ventil, variation, evolution
  )

tab_imp <- rbind(tab_intro, tab_exped)

### Révision des imputations des mois précédents
histo_rev <-
  arrow::open_dataset(
    sources = base_historique
  ) %>%
  distinct(siren, period, prediction, mois_ref, source, flux) %>%
  filter(source == "chiffre") %>%
  group_by(period, mois_ref, source, flux) %>%
  summarise(
    montant_imput = sum(prediction, na.rm = T),
    .groups = "drop"
  ) %>%
  arrange(period, mois_ref) %>%
  collect() %>%
  pivot_wider(names_from = mois_ref, values_from = montant_imput, names_prefix = "chiffre_") %>%
  select(-c(source))

revisions_intro <- revis_lastm(ventil_intro, histo_rev %>% filter(flux == "intro"))
revisions_exped <- revis_lastm(ventil_exped, histo_rev %>% filter(flux == "exped"))

# Mise en forme pour export des données au format XLSX ------

## Création du classeur XLSX -------
wb <- xlsx::createWorkbook(type = "xlsx")

## Definition des styles ---------

### Titre et sous-titre ----
TITLE_STYLE <- CellStyle(wb) +
  Font(wb,
    heightInPoints = 16,
    color = "blue", isBold = TRUE
  )

SUB_TITLE_STYLE <- CellStyle(wb) +
  Font(wb,
    heightInPoints = 14,
    isItalic = TRUE, isBold = FALSE
  )

### Styles pour le nom des lignes/colonnes ----
TABLE_ROWNAMES_STYLE <- CellStyle(wb) + Font(wb, isBold = TRUE)
TABLE_COLNAMES_STYLE <- CellStyle(wb) +
  Font(wb, isBold = TRUE) +
  Fill(backgroundColor = "lavender") +
  Alignment(wrapText = TRUE, horizontal = "ALIGN_CENTER") +
  Border(
    color = "black", position = c("TOP", "BOTTOM"),
    pen = c("BORDER_THIN", "BORDER_THICK")
  )

### Styles pour les colonnes -------
dfdate <- DataFormat("mmm-yyyy")
dfdate_2 <- DataFormat("dd/mm/yyyy")
dfnum <- DataFormat("#,##0")
dfpc <- DataFormat("0.0%")
dfsiren <- DataFormat('###" "###" "###')

cs1 <- CellStyle(wb, dataFormat = dfdate) +
  Alignment(horizontal = "ALIGN_LEFT")
cs1b <- CellStyle(wb, dataFormat = dfdate_2) +
  Alignment(horizontal = "ALIGN_LEFT")
cs2 <- CellStyle(wb, dataFormat = dfnum)
cs3 <- CellStyle(wb, dataFormat = dfpc)
cs4 <- CellStyle(wb, dataFormat = dfsiren) +
  Alignment(horizontal = "ALIGN_LEFT", indent = 1)

## onglet "Résultats des contrôles" ----
sheet <- xlsx::createSheet(wb, sheetName = "Resultats des controles")

### Ajouter un titre -----
xlsx.addTitle(sheet,
  rowIndex = 1,
  title = paste0(
    "Controles des imputations du ",
    prod, " de ",
    paste0(
      lubridate::month(ymd(mstat),
        label = TRUE
      ),
      " ", year(ymd(mstat))
    )
  ),
  titleStyle = TITLE_STYLE
)

### Ajouter tab_imp ----
xlsx.addTitle(sheet,
  rowIndex = 3,
  title = "Comparaison entre le fichier des imputations et celui des ventilations",
  titleStyle = SUB_TITLE_STYLE
)

addDataFrame(tab_imp, sheet,
  startRow = 4,
  startColumn = 1,
  colnamesStyle = TABLE_COLNAMES_STYLE,
  row.names = FALSE,
  colStyle = list(
    `2` = cs2, `3` = cs2, `4` = cs2,
    `5` = cs2, `6` = cs2, `7` = cs2, `8` = cs3
  )
)

### Ajouter revisions_intro ----
xlsx.addTitle(sheet,
  rowIndex = 8,
  title = "Revisions des imputations des mois precedents pour les introductions : ",
  titleStyle = SUB_TITLE_STYLE
)

addDataFrame(revisions_intro, sheet,
  startRow = 9,
  startColumn = 1,
  colnamesStyle = TABLE_COLNAMES_STYLE,
  row.names = FALSE,
  colStyle = list(
    `1` = cs1, `2` = cs2, `3` = cs2,
    `4` = cs2, `5` = cs2, `6` = cs2,
    `7` = cs2, `8` = cs2, `9` = cs3,
    `10` = cs3, `11` = cs3
  )
)

### Ajouter revisions_exped ----
xlsx.addTitle(sheet,
  rowIndex = nrow(revisions_intro) + 11,
  title = "Revisions des imputations des mois precedents pour les expeditions : ",
  titleStyle = SUB_TITLE_STYLE
)

addDataFrame(revisions_exped, sheet,
  startRow = nrow(revisions_intro) + 12,
  startColumn = 1,
  colnamesStyle = TABLE_COLNAMES_STYLE,
  row.names = FALSE,
  colStyle = list(
    `1` = cs1, `2` = cs2, `3` = cs2,
    `4` = cs2, `5` = cs2, `6` = cs2,
    `7` = cs2, `8` = cs2, `9` = cs3,
    `10` = cs3, `11` = cs3
  )
)

### Changer la largeur des colonnes ----
setColumnWidth(sheet, colIndex = c(1:11), colWidth = 15)



## onglet "Imputations - intro" ----
xlsx.addOngetImput(
  sheetName = "Imputations - intro",
  fichName = filePC_imp_intro,
  df1 = tot_imp_intro,
  df2 = split_imp_intro,
  df3 = meth_imp_intro
)

## onglet "Imputations - exped21" -----
xlsx.addOngetImput(
  sheetName = "Imputations - exped21",
  fichName = filePC_imp_exped21,
  df1 = tot_imp_exped21,
  df2 = split_imp_exped21,
  df3 = meth_imp_exped21
)

## onglet "Imputations - exped29" -----

xlsx.addOngetImput(
  sheetName = "Imputations - exped29",
  fichName = filePC_imp_exped29,
  df1 = tot_imp_exped29,
  df2 = split_imp_exped29,
  df3 = meth_imp_exped29
)

## onglet "Ventilations - intro" ----
xlsx.addOngetVentil(
  sheetName = "Ventilations - intro",
  fichName = filePC_ventil_intro,
  df1 = siren_ventil_intro,
  df2 = nmctr_ventil_intro,
  df3 = imp_ventil_intro,
  df4 = list_i_pyod,
  df5 = list_i_payp
)

## onglet "Ventilations - exped" ----
xlsx.addOngetVentil(
  sheetName = "Ventilations - exped",
  fichName = filePC_ventil_exped,
  df1 = siren_ventil_exped,
  df2 = nmctr_ventil_exped,
  df3 = imp_ventil_exped,
  df4 = list_e_pyod,
  df5 = list_e_payp
)

## onglet "Ventilations - exped21" ----
xlsx.addOngetVentil2(
  sheetName = "Ventilations - exped21",
  fichName = filePC_ventil_exped,
  df1 = siren_ventil_exped21,
  df2 = nmctr_ventil_exped21,
  df3 = imp_ventil_exped21
)


## onglet "Ventilations - exped29" -----
xlsx.addOngetVentil2(
  sheetName = "Ventilations - exped29",
  fichName = filePC_ventil_exped,
  df1 = siren_ventil_exped29,
  df2 = nmctr_ventil_exped29,
  df3 = imp_ventil_exped29
)


## onglet "Siren 10M - intro" ----
sheet <- xlsx::createSheet(wb, sheetName = "Siren 10M - intro")

### Ajouter un titre ----
xlsx.addTitle(sheet,
  rowIndex = 1,
  title = paste0("Siren des introductions avec une imputation de 10 millions ou plus"),
  titleStyle = TITLE_STYLE
)

### Ajouter list_i_siren10M ----
addDataFrame(list_i_siren10M, sheet,
  startRow = 3,
  startColumn = 1,
  colnamesStyle = TABLE_COLNAMES_STYLE,
  row.names = FALSE,
  colStyle = list(`1` = cs1, `2` = cs4, `5` = cs2, `7` = cs1b)
)

setColumnWidth(sheet, colIndex = c(1:2), colWidth = 15)
setColumnWidth(sheet, colIndex = c(3), colWidth = 50)
setColumnWidth(sheet, colIndex = c(4:10), colWidth = 15)


## onglet "Siren 10M - exped" ----
sheet <- xlsx::createSheet(wb, sheetName = "Siren 10M - exped")

### Ajouter un titre ----
xlsx.addTitle(sheet,
  rowIndex = 1,
  title = paste0("Siren des expeditions avec une imputation de 10 millions ou plus"),
  titleStyle = TITLE_STYLE
)

### Ajouter list_e_siren10M ----
addDataFrame(list_e_siren10M, sheet,
  startRow = 3,
  startColumn = 1,
  colnamesStyle = TABLE_COLNAMES_STYLE,
  row.names = FALSE,
  colStyle = list(`1` = cs1, `2` = cs4, `5` = cs2, `7` = cs1b)
)

setColumnWidth(sheet, colIndex = c(1:2), colWidth = 15)
setColumnWidth(sheet, colIndex = c(3), colWidth = 50)
setColumnWidth(sheet, colIndex = c(4:10), colWidth = 15)

## Enregistrer le classeur -----
xlsx::saveWorkbook(wb, file.path(Path_PC, paste0(
  "Controles_Pre-chiffre_refactor_",
  mstat, ".xlsx"
)))

## Sauvegardes fichier histo_rev (pour mémoire) ----
saveRDS(histo_rev, "data/histo_rev.rds")
