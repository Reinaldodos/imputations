####################################################################
### Construction du fichier des imputations par NATR pour la BdF ###
####################################################################

library(tidyverse)

################
### Fonction ###
################

pass_natr2022 <- function(x, ...){
  ### Permet de passer les anciens codes nature de transaction vers la nouvelle
  ### nomenclature de 2022.
  ### Concernant l'attribution du nouveau code 12, il faut attendre les premières 
  ### réponses à l'enquête pour calculer une part des codes 11 à passer en 12.
  
  colnames(x) <- toupper(colnames(x))
  x$NATR <- as.character(x$NATR)
  x$NC4 <- substr(as.character(x$NC8), 1, 4)
  
  # Codification des valeurs manquantes en 00
  x[is.na(x$NATR), c("NATR")] <- "00"
  
  # Changements des codes natr
  x$NATR22 <- x$NATR
  x[x$NATR == "12",c("NATR22")] <- "32"
  x[x$NATR == "13",c("NATR22")] <- "34"
  x[x$NATR == "14",c("NATR22")] <- "33"
  x[x$NATR == "19",c("NATR22")] <- "31"
  x[x$NATR == "29",c("NATR22")] <- "99"
  x[x$NATR == "30",c("NATR22")] <- "34"
  x[x$NATR == "70" & x$NC4 != "8802", c("NATR22")] <- "11"
  x[x$NATR == "70" & x$NC4 == "8802" & x$FLUX == "I", c("NATR22")] <- "51"
  x[x$NATR == "70" & x$NC4 == "8802" & x$FLUX == "E", c("NATR22")] <- "41"
  
  return(x)
}



###################################
### Importation des imputations ###
###################################

path_FI <- output_directory

### ATTENTION AUX NA POUR LA NANIBIE


file_intro=list.files(path_FI,pattern = "ventil_intro_ref",full.names = F)

### Introductions
imp_intro <- (read.csv2(file = file.path(path_FI, file_intro)
                       ,sep = ";"
                       ,colClasses = c(siren = "character")
                       ,na.strings = c(""," "))
              %>% mutate(adep = substr(period, 1, 4)
                        ,mdep = substr(period, 6, 7)
                        ,flux = "I"
                        ,pyod = ifelse(is.na(pyod), "QU", pyod)
                        ,pyod = ifelse(pyod %in% c("XU", "XI"), "GB", pyod)
                        ,pyod = ifelse(pyod %in% c("QR", "QS", "EU", "QQ"), "QU", pyod)
                        ,payp = ifelse(is.na(payp) & pyod != "YT", pyod, payp)
                        ,payp = ifelse(is.na(payp) & pyod == "YT", "QU", payp)
                        ,payp = ifelse(payp %in% c("XU", "XI"), "GB", payp)
                        ,payp = ifelse(payp %in% c("QR", "QS", "EU", "QQ"), "QU", payp)
                        ,payp = ifelse(payp == "FR" & pyod == "FR", "QU", payp)
                        ,payp = ifelse(payp == "FR" & pyod != "FR", pyod, payp))
              %>% filter(!is.na(nc8))
              %>% select(flux, adep, mdep, pyod, payp
                         ,natr, nc8, dist_prediction))


### Exportations
file_exped=list.files(path_FI,pattern = "ventil_exped_ref",full.names = F)
imp_exped <- (read.csv2(file = file.path(path_FI, file_exped)
                        ,sep = ";"
                        ,colClasses = c(siren = "character")
                        ,na.strings = c(""," "))
              %>% mutate(adep = substr(period, 1, 4)
                         ,mdep = substr(period, 6, 7)
                         ,flux = "E"
                         ,pyod = ifelse(is.na(pyod), "QU", pyod)
                         ,pyod = ifelse(pyod %in% c("XU", "XI"), "GB", pyod)
                         ,pyod = ifelse(pyod %in% c("QR", "QS", "EU", "QQ"), "QU", pyod)
                         ,payp = "")
              %>% filter(!is.na(nc8))
              %>% select(flux, adep, mdep, pyod, payp, natr
                         ,nc8, dist_prediction))


# Jointure des tables des importations et des expéditions
imp <- rbind(imp_intro, imp_exped, make.row.names = FALSE)
rm(imp_intro, imp_exped)


###############################
### Recodage des codes NATR ###
###############################
imp <- pass_natr2022(imp)
  
##############################################
### Agrégation des données par code NATR22 ###
##############################################
imp_bdf <- aggregate(DIST_PREDICTION ~ FLUX+ADEP+MDEP+PYOD+PAYP+NATR22
                      ,data = imp
                      ,sum) %>% 
                    mutate(IMPUTATION = round(DIST_PREDICTION, digits = 0)) %>% 
                      select(-DIST_PREDICTION) %>% 
                        arrange(FLUX, desc(ADEP), desc(MDEP), PYOD, PAYP, NATR22)


###############################
### Ecriture du fichier csv ###
###############################
write.table(imp_bdf, file = file.path(path_FI,"imputations_NATR.txt"),
            sep = ";", quote = FALSE,
            col.names = FALSE,
            row.names = FALSE)
# rm(imp,imp_bdf)