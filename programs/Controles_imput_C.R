### Packages ###
################
library(tidyverse)
library(xlsx)
library(lubridate)
#_______________________________________________________________________________

### Date statistique à mettre à jour ###
########################################
mstat <- "2022-06-01" 
#_______________________________________________________________________________

### Variables d'environemment ###
#################################

## Type de production
prod = "Chiffre"

## Chemins
path_ech <- "Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/échantillon/échantillon 202201/datas"
Path_Data <- file.path("../data")
Path_Prod <- file.path(paste0("../production_", 
                              year(ymd(mstat)), 
                              sprintf("%02d", month(ymd(mstat)))))

Path_PC <- file.path(Path_Prod, "output_PC")
Path_C <- file.path(Path_Prod, "output_C")

## Noms des fichiers
file_ech <- "echantillon_actualise_2022_01-s5v9-pour stats.csv"
file_pyod <- "PYOD_partners.xlsx"
file_NC82022 <- "NC8_22 vers CPF6_A129.csv"

fileC_imp_intro <- list.files(Path_C,
                              pattern = paste0("estim_intro_",
                                               year(ymd(mstat)), 
                                               sprintf("%02d", 
                                                       month(ymd(mstat)))))[1]

fileC_imp_exped21 <- list.files(Path_C,
                                pattern = paste0("estim_exped_21_",
                                                 year(ymd(mstat)), 
                                                 sprintf("%02d", 
                                                         month(ymd(mstat)))))[1]

fileC_imp_exped29 <- list.files(Path_C,
                                pattern = paste0("estim_exped_29_",
                                                 year(ymd(mstat)), 
                                                 sprintf("%02d", 
                                                         month(ymd(mstat)))))[1]

fileC_ventil_intro <- list.files(Path_C,
                                 pattern = "ventil_intro")[1]

fileC_ventil_exped <- list.files(Path_C,
                                 pattern = "ventil_exped")[1]


filePC_ventil_intro <- list.files(Path_PC,
                                  pattern = "ventil_intro")[1]

filePC_ventil_exped <- list.files(Path_PC,
                                  pattern = "ventil_exped")[1]
#_______________________________________________________________________________


### Fonctions ###
#################
source(file = "fonctions_controles.R", encoding = "UTF-8")

######################################
### Lecture des tables de passages ###
######################################
file_pyod <- "PYOD_partners.xlsx"
file_NC82022 <- "NC8_22 vers CPF6_A129.csv"

###############################
### Lecture des imputations ###
###############################

## Introductions
imput_intro <- read.csv2(file = file.path(Path_C, fileC_imp_intro),
                         sep = ";", 
                         colClasses = c(siren="character")) %>%  
  select(siren, period, prediction, method, method_ref)

## Expéditions
imput_exped21 <- read.csv2(file = file.path(Path_C, fileC_imp_exped21),
                           sep = ";", 
                           colClasses = c(siren="character")) %>%
  select(siren, period, prediction, method, method_ref)

imput_exped29 <- read.csv2(file = file.path(Path_C, fileC_imp_exped29),
                           sep = ";", 
                           colClasses = c(siren="character")) %>% 
  select(siren, period, prediction, method, method_ref)

imput_exped <- rbind(imput_exped21, imput_exped29)
imput_exped <- aggregate(prediction~siren+period, data = imput_exped, sum)

################################
### Lecture des ventilations ###
################################

## Introductions
ventil_intro <- read.csv2(file = file.path(Path_C, fileC_ventil_intro),
                          sep = ";", na.strings = TRUE,
                          colClasses = c(siren = "character",
                                         nc8 = "character")) %>% 
  filter(!is.na(dist_prediction))



## Expéditions
ventil_exped <- read.csv2(file = file.path(Path_C, fileC_ventil_exped),
                          sep = ";", na.strings = TRUE,
                          colClasses = c(siren = "character",
                                         nc8 = "character")) %>% 
  filter(!is.na(dist_prediction))

ventil_exped21 <- ventil_exped %>% filter(regdem == 21)
ventil_exped29 <- ventil_exped %>% filter(regdem == 29)

### Pré-chiffre
ventilPC_intro <- read.csv2(file = file.path(Path_PC, filePC_ventil_intro),
                            sep = ";", na.strings = TRUE,
                            colClasses = c(siren = "character",
                                           nc8 = "character")) %>% 
  filter(!is.na(dist_prediction))

ventilPC_exped <- read.csv2(file = file.path(Path_PC, filePC_ventil_exped),
                            sep = ";", na.strings = TRUE,
                            colClasses = c(siren = "character",
                                           nc8 = "character")) %>% 
  filter(!is.na(dist_prediction))


###################################
### Tables des pays et NC8 2022 ###
###################################
list_pyod <- read.xlsx(file=file.path(Path_Data, file_pyod), 1)
list_partners <- read.xlsx(file=file.path(Path_Data, file_pyod), 2)
list_nc82022 <- read.csv2(file = file.path(Path_Data, file_NC82022),
                          sep = ";",
                          colClasses = "character")

#################################
### Controles des imputations ###
#################################
tot_imp_intro <-  ctrl_tot_imp(imput_intro)

split_imp_intro <- ctrl_class_imp(imput_intro)
meth_imp_intro <- ctrl_method_imp(imput_intro)

tot_imp_exped21 <-  ctrl_tot_imp(imput_exped21)
split_imp_exped21 <- ctrl_class_imp(imput_exped21)
meth_imp_exped21 <- ctrl_method_imp(imput_exped21)

tot_imp_exped29 <-  ctrl_tot_imp(imput_exped29)
split_imp_exped29 <- ctrl_class_imp(imput_exped29)
meth_imp_exped29 <- ctrl_method_imp(imput_exped29)

tot_imp_exped <-  ctrl_tot_imp(imput_exped)
split_imp_exped <- ctrl_class_imp(imput_exped)

### Extraction liste des siren avec une imputation >= 10 millions
list_i_siren10M <- list_seuil_pred(ventil_intro, 10000000)
list_e_siren10M <- list_seuil_pred(ventil_exped, 10000000)

### Appariement des siren imputés avec sirene
fi <- function(x, pos) subset(x, siren %in% unique(list_i_siren10M$siren))
lsir_i <- read_csv_chunked('../data/StockUniteLegale_utf8.csv', 
                           callback = DataFrameCallback$new(fi),
                           chunk_size = 1000000)%>% 
  select("siren", "etatAdministratifUniteLegale",
         "denominationUniteLegale", "activitePrincipaleUniteLegale")

list_i_siren10M <- list_i_siren10M %>% 
  left_join(lsir_i, by = "siren") %>% 
  relocate("period", "siren", "denominationUniteLegale",
           "activitePrincipaleUniteLegale", "prediction", 
           "etatAdministratifUniteLegale") %>% 
  rename(raison.sociale=denominationUniteLegale,
         APE=activitePrincipaleUniteLegale,
         etat=etatAdministratifUniteLegale) %>% 
  arrange("period", desc("prediction"))


fe <- function(x, pos) subset(x, siren %in% unique(list_e_siren10M$siren))
lsir_e <- read_csv_chunked('../data/StockUniteLegale_utf8.csv', 
                           callback = DataFrameCallback$new(fe),
                           chunk_size = 1000000)%>% 
  select("siren", "etatAdministratifUniteLegale",
         "denominationUniteLegale", "activitePrincipaleUniteLegale")

list_e_siren10M <- list_e_siren10M %>% 
  left_join(lsir_e, by = "siren") %>% 
  relocate("period", "siren", "denominationUniteLegale",
           "activitePrincipaleUniteLegale", "prediction", 
           "etatAdministratifUniteLegale") %>%
  rename(raison.sociale=denominationUniteLegale,
         APE=activitePrincipaleUniteLegale,
         etat=etatAdministratifUniteLegale) %>% 
  arrange("period", desc("prediction"))

### Appariement des siren imputés avec l'échantillon
echantillon <- read.csv2(file.path(path_ech, file_ech),
                         sep =";",
                         encoding = "UTF-8") %>% 
  select(siren, centre_stat_rattachement, IDF, lille, dnsce, type.d.enquête) %>% 
  mutate(siren = sprintf("%09d", siren))

ech_i <- echantillon %>% 
  filter(type.d.enquête %in% c("intro", "intro+exped"),
         siren %in% unique(list_i_siren10M$siren)) %>% 
  select(-c(type.d.enquête))

list_i_siren10M <- list_i_siren10M %>% 
  left_join(ech_i, by = "siren")

ech_e <- echantillon %>% 
  filter(type.d.enquête %in% c("expéd", "intro+exped"),
         siren %in% unique(list_e_siren10M$siren)) %>% 
  select(-c(type.d.enquête))

list_e_siren10M <- list_e_siren10M %>% 
  left_join(ech_e, by = "siren")

##################################
### Controles des ventilations ###
##################################
siren_ventil_intro <- ctrl_siren_ventil(ventil_intro)
nmctr_ventil_intro <- ctrl_nmctr_ventil(ventil_intro)
imp_ventil_intro <- ctrl_imp_ventil(ventil_intro)

list_i_pyod <- ventil_intro %>% 
  filter(period == mstat) %>% 
  distinct(pyod) %>% 
  filter(!(pyod %in% list_pyod$CODE))
if(nrow(list_i_pyod)==0){list_i_pyod[1,1] <- "Aucune"}

list_i_payp <- ventil_intro %>% 
  filter(period == mstat) %>% 
  distinct(payp) %>% 
  filter(!(payp %in% list_partners$CODE))
if(nrow(list_i_payp)==0){list_i_payp[1,1] <- "Aucune"}

siren_ventil_exped21 <- ctrl_siren_ventil(ventil_exped21)
nmctr_ventil_exped21 <- ctrl_nmctr_ventil(ventil_exped21)
imp_ventil_exped21 <- ctrl_imp_ventil(ventil_exped21)

siren_ventil_exped29 <- ctrl_siren_ventil(ventil_exped29)
nmctr_ventil_exped29 <- ctrl_nmctr_ventil(ventil_exped29)
imp_ventil_exped29 <- ctrl_imp_ventil(ventil_exped29)

siren_ventil_exped <- ctrl_siren_ventil(ventil_exped)
nmctr_ventil_exped <- ctrl_nmctr_ventil(ventil_exped)
imp_ventil_exped <- ctrl_imp_ventil(ventil_exped)

list_e_pyod <- ventil_exped %>% 
  filter(period == mstat) %>% 
  distinct(pyod) %>%
  filter(!(pyod %in% list_partners$CODE))
if(nrow(list_e_pyod)==0){list_e_pyod[1,1] <- "Aucune"} 

list_e_payp <- ventil_exped %>% 
  filter(period == mstat) %>% 
  distinct(payp) %>% 
  filter(!(payp %in% list_pyod$CODE))
if(nrow(list_e_payp)==0 | (nrow(list_e_payp)==1 & list_e_payp[1,1]=="")){
  list_e_payp[1,1] <- "Aucune"}


############################
### Tables des résultats ###
############################

### Comparaison des imputations vs ventilations
tab_intro <- tot_imp_intro %>%
  left_join(siren_ventil_intro, by = "period") %>% 
  select(period, siren_imp, imputation, siren_ventil) %>% 
  left_join(imp_ventil_intro, by = "period") %>% 
  select(siren_imp, imputation, siren_ventil, tot_imput) %>%
  rename(imput_ventil = tot_imput) %>% 
  mutate(flux = "Introductions",
         diff_siren = siren_imp - siren_ventil,
         variation = imput_ventil-imputation,
         evolution = variation/imputation) %>% 
  relocate(flux, siren_imp, siren_ventil, diff_siren,
           imputation, imput_ventil, variation, evolution)


tab_exped <- tot_imp_exped %>%
  left_join(siren_ventil_exped, by = "period") %>% 
  select(period, siren_imp, imputation, siren_ventil) %>% 
  left_join(imp_ventil_exped, by = "period") %>% 
  select(siren_imp, imputation, siren_ventil, tot_imput) %>% 
  rename(imput_ventil = tot_imput) %>% 
  mutate(flux = "Expéditions",
         diff_siren = siren_imp - siren_ventil,
         variation = imput_ventil-imputation,
         evolution = variation/imputation) %>% 
  relocate(flux, siren_imp, siren_ventil, diff_siren,
           imputation, imput_ventil, variation, evolution)

tab_imp <- rbind(tab_intro, tab_exped)

### Révisions Pré-chiffre - chiffre

siren_ventilPC_intro <- ctrl_siren_ventil(ventilPC_intro)
imp_ventilPC_intro <- ctrl_imp_ventil(ventilPC_intro)

tot_ventilPC_intro <- siren_ventilPC_intro %>% 
  filter(period == mstat) %>% 
  select(period, siren_ventil) %>% 
  left_join(imp_ventilPC_intro, by = "period") %>% 
  select(siren_ventil, tot_imput) %>% 
  rename(siren_PC = siren_ventil, imput_PC = tot_imput) %>% 
  mutate(flux = "Introductions") %>% 
  relocate(flux)

siren_ventilPC_exped <- ctrl_siren_ventil(ventilPC_exped)
imp_ventilPC_exped <- ctrl_imp_ventil(ventilPC_exped)

tot_ventilPC_exped <- siren_ventilPC_exped %>% 
  filter(period == mstat) %>% 
  select(period, siren_ventil) %>% 
  left_join(imp_ventilPC_exped, by = "period") %>% 
  select(siren_ventil, tot_imput) %>% 
  rename(siren_PC = siren_ventil, imput_PC = tot_imput) %>% 
  mutate(flux = "Expéditions") %>% 
  relocate(flux)

PC_ventil <- rbind(tot_ventilPC_intro, tot_ventilPC_exped)

tab_rev_PC <- tab_imp %>% rename(siren_C = siren_imp, imput_C = imput_ventil) %>%
  select(flux, siren_C, imput_C) %>% 
  left_join(PC_ventil, by = "flux") %>% 
  mutate(diff_siren = siren_PC - siren_C,
         variation = imput_C - imput_PC,
         evolution = variation / imput_PC) %>% 
  relocate(flux, siren_PC, siren_C, diff_siren, 
           imput_PC, imput_C, variation, evolution)


### Révisions introductions
histo_rev_intro <- readRDS(file.path(Path_Data ,"histo_rev_intro.Rds"))
revisions_intro <- revis_lastm(ventil_intro, histo_rev_intro)

histo_rev_intro <- histo_m(ventil_intro, histo_rev_intro)
saveRDS(histo_rev_intro, file.path(Path_Data ,"histo_rev_intro.Rds"))

### Révisions expéditions
histo_rev_exped <- readRDS(file.path(Path_Data ,"histo_rev_exped.Rds"))
revisions_exped <- revis_lastm(ventil_exped, histo_rev_exped)

histo_rev_exped <- histo_m(ventil_exped, histo_rev_exped)
saveRDS(histo_rev_exped, file.path(Path_Data ,"histo_rev_exped.Rds"))

#################################
### Création du classeur XLSX ###
#################################

wb <- createWorkbook(type="xlsx")

## Definition des styles

# Titre et sous-titre
TITLE_STYLE <- CellStyle(wb) + 
  Font(wb,  heightInPoints=16, 
       color="blue", isBold=TRUE)

SUB_TITLE_STYLE <- CellStyle(wb) + 
  Font(wb,  heightInPoints=14,
       isItalic=TRUE, isBold=FALSE)

# Styles pour le nom des lignes/colonnes
TABLE_ROWNAMES_STYLE <- CellStyle(wb) + Font(wb, isBold=TRUE)
TABLE_COLNAMES_STYLE <- CellStyle(wb) + 
  Font(wb, isBold=TRUE) +
  Fill(backgroundColor = "lavender") +
  Alignment(wrapText=TRUE, horizontal="ALIGN_CENTER") +
  Border(color="black", position=c("TOP", "BOTTOM"), 
         pen=c("BORDER_THIN", "BORDER_THICK"))

# Styles pour les colonnes
dfdate <- DataFormat('mmm-yyyy')
dfnum <-  DataFormat('#,##0')
dfpc <- DataFormat('0.0%')
dfsiren <- DataFormat('###" "###" "###')

cs1 <- CellStyle(wb, dataFormat=dfdate) +
  Alignment(horizontal="ALIGN_LEFT")
cs2 <- CellStyle(wb, dataFormat=dfnum)
cs3 <- CellStyle(wb, dataFormat=dfpc)
cs4 <- CellStyle(wb, dataFormat=dfsiren) +
  Alignment(horizontal="ALIGN_LEFT", indent = 1)

# onglet "Résultats des contrôles"
#---------------------------------
sheet <- createSheet(wb, sheetName = "Résultats des contrôles")

# Ajouter un titre
xlsx.addTitle(sheet, rowIndex=1, 
              title=paste0("Contrôles des imputations du ",
                           prod, " de ",
                           paste0(month(ymd(mstat), 
                                        label=TRUE),
                                  " ", year(ymd(mstat)))),
              titleStyle = TITLE_STYLE)

# Ajouter tab_imp
xlsx.addTitle(sheet, rowIndex=3, 
              title="Comparaison entre le fichier des imputations et celui des ventilations",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(tab_imp, sheet, startRow=4,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`2`=cs2, `3`=cs2,`4`=cs2,
                           `5`=cs2, `6`=cs2,`7`=cs2, `8`=cs3))


# Ajouter revisions_PC
xlsx.addTitle(sheet, rowIndex=8, 
              title="Révion entre le Pré-chiffre et le Chiffre : ",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(tab_rev_PC, sheet, startRow=9,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`2`=cs2, `3`=cs2,`4`=cs2,
                           `5`=cs2, `6`=cs2,`7`=cs2, `8`=cs3))

# Ajouter revisions_intro
xlsx.addTitle(sheet, rowIndex=13, 
              title="Révisions des imputations des mois précédents pour les introductions : ",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(revisions_intro, sheet, startRow=14,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                           `4`=cs2, `5`=cs2, `6`=cs2,
                           `7`=cs2, `8`=cs2, `9`=cs3,
                           `10`=cs3, `11`=cs3))

# Ajouter revisions_exped
xlsx.addTitle(sheet, 
              rowIndex=nrow(revisions_intro) + 16, 
              title="Révisions des imputations des mois précédents pour les expéditions : ",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(revisions_exped, sheet, 
             startRow=nrow(revisions_intro) + 17,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`1`=cs1, `2`=cs2, `3`=cs2,
                           `4`=cs2, `5`=cs2, `6`=cs2,
                           `7`=cs2, `8`=cs2, `9`=cs3,
                           `10`=cs3, `11`=cs3))

# Changer la largeur des colonnes
setColumnWidth(sheet, colIndex=c(1:11), colWidth=15)


# onglet "Imputations - intro"
#-----------------------------
xlsx.addOngetImput(sheetName = "Imputations - intro",
                   fichName = fileC_imp_intro,
                   df1 = tot_imp_intro,
                   df2 = split_imp_intro,
                   df3 = meth_imp_intro)

# onglet "Imputations - exped21"
#-------------------------------
xlsx.addOngetImput(sheetName = "Imputations - exped21",
                   fichName = fileC_imp_exped21,
                   df1 = tot_imp_exped21,
                   df2 = split_imp_exped21,
                   df3 = meth_imp_exped21)

# onglet "Imputations - exped29"
#-------------------------------
xlsx.addOngetImput(sheetName = "Imputations - exped29",
                   fichName = fileC_imp_exped29,
                   df1 = tot_imp_exped29,
                   df2 = split_imp_exped29,
                   df3 = meth_imp_exped29)

# onglet "Ventilations - intro"
#------------------------------
xlsx.addOngetVentil(sheetName = "Ventilations - intro",
                    fichName = fileC_ventil_intro,
                    df1 = siren_ventil_intro,
                    df2 = nmctr_ventil_intro,
                    df3 = imp_ventil_intro,
                    df4 = list_i_pyod,
                    df5 = list_i_payp)

# onglet "Ventilations - exped"
#------------------------------
xlsx.addOngetVentil(sheetName = "Ventilations - exped",
                    fichName = fileC_ventil_exped,
                    df1 = siren_ventil_exped,
                    df2 = nmctr_ventil_exped,
                    df3 = imp_ventil_exped,
                    df4 = list_e_pyod,
                    df5 = list_e_payp)

# onglet "Ventilations - exped21"
#------------------------------
xlsx.addOngetVentil2(sheetName = "Ventilations - exped21",
                     fichName = fileC_ventil_exped,
                     df1 = siren_ventil_exped21,
                     df2 = nmctr_ventil_exped21,
                     df3 = imp_ventil_exped21)


# onglet "Ventilations - exped29"
#------------------------------
xlsx.addOngetVentil2(sheetName = "Ventilations - exped29",
                     fichName = fileC_ventil_exped,
                     df1 = siren_ventil_exped29,
                     df2 = nmctr_ventil_exped29,
                     df3 = imp_ventil_exped29)


# onglet "Siren 10M - intro"
#------------------------------
sheet <- createSheet(wb, sheetName = "Siren 10M - intro")

# Ajouter un titre
xlsx.addTitle(sheet, rowIndex=1, 
              title=paste0("Siren des introductions avec une imputation de 10 millions ou plus"),
              titleStyle = TITLE_STYLE)

# Ajouter list_i_siren10M
addDataFrame(list_i_siren10M, sheet, startRow=3,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`1`=cs4, `2`=cs1, `3`=cs2))

setColumnWidth(sheet, colIndex=c(1:2), colWidth=15)
setColumnWidth(sheet, colIndex=c(3), colWidth=50)
setColumnWidth(sheet, colIndex=c(4:10), colWidth=15)

# onglet "Siren 10M - exped"
#------------------------------
sheet <- createSheet(wb, sheetName = "Siren 10M - exped")

# Ajouter un titre
xlsx.addTitle(sheet, rowIndex=1, 
              title=paste0("Siren des expéditions avec une imputation de 10 millions ou plus"),
              titleStyle = TITLE_STYLE)

# Ajouter list_e_siren10M
addDataFrame(list_e_siren10M, sheet, startRow=3,
             startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             row.names = FALSE,
             colStyle=list(`1`=cs4, `2`=cs1, `3`=cs2))

setColumnWidth(sheet, colIndex=c(1:2), colWidth=15)
setColumnWidth(sheet, colIndex=c(3), colWidth=50)
setColumnWidth(sheet, colIndex=c(4:10), colWidth=15)

# Enregistrer le classeur 
#+++++++++++++++++++++++++
saveWorkbook(wb, file.path(Path_C, paste0("Controles_Chiffre_",
                                          mstat, ".xlsx")))


