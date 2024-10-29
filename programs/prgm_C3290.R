library(tidyverse)
library(rio)

path_pass <- file.path(freenas_directory, "traitement non-réponse", "data")
path_imput <- output_directory

########################
### Table de passage ###
########################

Tpass <- read.csv2(file.path(path_pass, "ngp9_2022_2016.csv"),
                   sep =";", na.strings = FALSE,
                   colClasses = "character") %>% 
          mutate(nc8 = substr(ngp9,1,8))

Tbl_pass <- Tpass %>% group_by(nc8) %>% 
            mutate(n = 1:n()) %>% 
              filter(n == min(n)) %>% 
                select(nc8, cpf)

###################
### Imputations ###
###################

### Introductions

file_intro=list.files(path_imput,pattern = "ventil_intro_ref",full.names = F)
annee=str_split_fixed(file_intro,pattern = "ref",n=2)[1,2] %>% str_sub(.,1,4)
mois=str_split_fixed(file_intro,pattern = "ref",n=2)[1,2] %>% str_sub(.,5,6)

intro <- read.csv2(file.path(path_imput, file_intro),
                   sep = ";", na.strings = FALSE,
                   colClasses = c(dist_prediction = "double")) %>% 
          filter(nc8 != "NA") %>% 
            mutate(flux = 1, 
                   pyod = ifelse(is.na(pyod), "NA", pyod),
                   nc8 = ifelse(nchar(nc8)<8, sprintf("%08d", nc8), nc8)) %>% 
              select(flux, nc8, pyod, dist_prediction)

### Expéditions
file_exped=list.files(path_imput,pattern = "ventil_exped_ref",full.names = F)

exped <- read.csv2(file.path(path_imput, file_exped),
                    sep = ";", na.strings = FALSE,
                    colClasses = c(dist_prediction = "double")) %>%
          filter(nc8 != "NA") %>%
            mutate(flux = 2, 
                   pyod = ifelse(is.na(pyod), "NA", pyod),
                   nc8 = ifelse(nchar(nc8)<8, sprintf("%08d", nc8), nc8)) %>% 
              select(flux, nc8, pyod, dist_prediction)

imput <- rbind(intro, exped, make.row.names = FALSE)

imput_nc8 <- aggregate(dist_prediction~nc8+pyod+flux, data = imput, sum) 

###########################
### Ajout des codes CPF ###
###########################

## Avec les NC8 de 2022
imput_cpf <- merge(imput_nc8, Tbl_pass, by = "nc8", all.x = TRUE)


### Aggregation par cpf
imputCPF <- aggregate(dist_prediction~flux+pyod+cpf, data = imput_cpf, sum)%>%
                     mutate(mdep = mois, adep = annee,
                            nc8 = "", quantite = "", usup = "",
                            imputation = round(dist_prediction, digits = 0)) %>% 
                      select(-dist_prediction) %>% 
                        relocate(flux, mdep, adep, nc8, cpf, pyod,
                                 imputation, quantite, usup) %>% 
                          arrange(flux, pyod, cpf)


###############################
### Ecriture du fichier csv ###
###############################
write.table(imputCPF, file = file.path(path_imput,paste0("imputCPF_",annee,mois,".TXT")),
            sep =";", col.names = FALSE, row.names = FALSE,
            quote = FALSE)

