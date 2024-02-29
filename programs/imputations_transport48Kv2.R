#################################################################
### fichier des imputations par type de transport pour la BdF ###
#################################################################
library(tidyverse)


###################################
### Importation des imputations ###
###################################

path_FI <- output_directory


### Introductions
file_intro=list.files(path_FI,pattern = "ventil_intro_ref",full.names = F)

imp_intro <- (read.csv2(file = file.path(path_FI, file_intro)
                        ,sep = ";"
                        ,colClasses = c(siren = "character")
                        ,na.strings = c(""," "))
              %>% mutate(adep = substr(period, 1, 4)
                         ,mdep = substr(period, 6, 7)
                         ,flux = "I"
                         ,pyod = ifelse(is.na(pyod), "QU", pyod)
                         ,pyod = ifelse(pyod %in% c("XI", "XU"), "GB", pyod)
                         ,payp = ifelse(is.na(payp), "QU", payp)
                         ,payp = ifelse(payp %in% c("XI", "XU"), "GB", payp)
                         ,temo = ifelse(is.na(temo), 3, temo))
              %>% filter(!is.na(nc8))
              %>% select(flux, adep, mdep, pyod, payp
                         ,temo, dist_prediction))

### Exportations
file_exped=list.files(path_FI,pattern = "ventil_exped_ref",full.names = F)

imp_exped <- (read.csv2(file = file.path(path_FI,file_exped)
                          ,sep = ";"
                          ,colClasses = c(siren = "character")
                        ,na.strings = c(""," "))
                %>% mutate(adep = substr(period, 1, 4)
                           ,mdep = substr(period, 6, 7)
                           ,flux = "E"
						   ,pyod = ifelse(is.na(pyod), "QU", pyod)
                           ,pyod = ifelse(pyod %in% c("XI", "XU"), "GB", pyod)
                           ,payp = ifelse(is.na(payp), "QU", payp)
                           ,payp = ifelse(payp %in% c("XI", "XU"), "GB", payp)
                           ,temo = ifelse(is.na(temo), 3, temo))
                %>% filter(!is.na(nc8))
                %>% select(flux, adep, mdep, pyod,
                           temo, dist_prediction))


# Jointure des tables des importations et des expéditions
imp_exped <- imp_exped %>% mutate(payp = "")
imp <- rbind(imp_intro, imp_exped, make.row.names = FALSE)
rm(imp_intro, imp_exped)

############################################
### Agrégation des données par code temo ###
############################################
imp_bdf <- aggregate(dist_prediction ~ flux+adep+mdep+pyod+payp+temo
                     ,data = imp
                     ,sum) %>% 
  mutate(imputation = round(dist_prediction, digits = 0), livr = "XXXX") %>% 
    select(-dist_prediction) %>% 
      arrange(flux, desc(adep), desc(mdep), pyod, payp, temo) %>%
        relocate(flux, adep, mdep, pyod, payp, livr, temo, imputation)


###############################
### Ecriture du fichier csv ###
###############################
write.table(imp_bdf, file = file.path(path_FI,"imputations_transport.txt"),
            sep = ";", quote = FALSE,
            col.names = FALSE,
            row.names = FALSE)


rm(imp,imp_bdf)
