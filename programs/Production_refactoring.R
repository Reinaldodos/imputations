pacman::p_load(lubridate,tidyverse)

options(scipen = 999)

source('config.R')

# A - recuperer les inputs -----------

## 1 -  fichier des ventilations detaillees de la non-reponse --------
# recuperer fichiers de ventilation
intro_ventil_rect <- readRDS(paste0(output_directory,"/intro_ventil_rect.rds"))
exped_ventil_rect <- readRDS(paste0(output_directory,"/exped_ventil_rect.rds"))

## table de passage CTCI/NC -----------
pass_names <- c('annee', 'ngp9', 'cpf6', 'a17', 'a38', 'a129', 'cpfrev1', 'nes114', 'ctci')

pass_file <- data.frame(
  files = c('11- fichier POLYCO2021.xls', '11- POLYCO2022.xls', '11_POLYCO2023_b.xlsx','11_POLYCO2024_b.xlsx'),
  skiprows = 1,
  directory = c('Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/data'),
  year = c(2021,2022,2023,2024), 
  cols = "A:I"
)

#recuperation des tables de passage
get_pass_table <- function(pass_file, file, pass_names){
  pass_data <- rio::import(file.path(
    pass_file[pass_file$files == file,]$directory, file
  ),
  range = readxl::cell_cols(pass_file[pass_file$files == file,]$cols),
  col_names = pass_names) %>%
    as_tibble() %>%
    subset(subset = (annee != "Année")) %>%
    mutate(year = as.integer(annee),
           nc8 = substr(ngp9, 1, 9))
  return(pass_data)
}

import_pass_table = function(pass_names){
    pass_data <- pass_file$files %>%
      map_df(~get_pass_table(pass_file = pass_file,
                             file = .x,
                             pass_names = pass_names)) %>%
      bind_rows() %>%
      mutate(nc8 = substr(ngp9, 1, 8)) %>%
      group_by(year, nc8, a129) %>%
      summarise(ctci = unique(ctci)) %>%
      ungroup()
    return(pass_data)
  }

pass_table = import_pass_table(pass_names)

#B - fonctions de production des fichiers

## 1 - production MATMIL / HORS MATMIL ----------------
GetNationalFormat = function(file_exped, file_introd, filename, exclu, matmil = T){
  if (matmil){
    exped <- file_exped %>%
      subset(subset = (conf == "3"))
    intro <- file_introd %>%
      subset(subset = (conf == "3"))
  }else{
    exped <- file_exped %>%
      subset(subset = !(conf == "3"))
    intro <- file_introd %>%
      subset(subset = !(conf == "3"))
  }
  exped <- (mutate(exped, adep = year(period), mdep = month(period), flux = 'E')
            %>% group_by(a129, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)))
  intro <- (mutate(intro, adep = year(period), mdep = month(period), flux = 'I')
            %>% group_by(a129, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)))
  result <- rbind(exped, intro) %>% subset(subset = (!(pyod %in% exclu) & !is.na(pyod) & (pyod != "") & 
                                                       !(is.na(a129)) & (a129 != "") & 
                                                       !is.na(adep) & (adep != "") & 
                                                       !is.na(mdep) & (mdep != "") & 
                                                       !is.na(vart)))
  write.csv2(result, filename, row.names = FALSE, na = "")
  return(result)
}

national_wo_matmil <- GetNationalFormat(
  file_exped = exped_ventil_rect, 
  file_introd = intro_ventil_rect, 
  filename = file.path(output_directory, 
                       sprintf("production_national_ref%s.csv", 
                               format(date_ref, "%Y%m"))), 
  exclu = c(), 
  matmil = F
)

national_matmil <- GetNationalFormat(
  file_exped = exped_ventil_rect, 
  file_introd = intro_ventil_rect, 
  filename = file.path(output_directory, 
                       sprintf("production_national_matmil_ref%s.csv", 
                               format(date_ref, "%Y%m"))), 
  exclu = c(), 
  matmil = T
)


## 2 - productions au format CTCI --------------
GetEurostatCTCIFormat = function(file_exped, file_introd,  filename, exclu){
            intro <- (mutate(file_introd, adep = year(period), mdep = month(period), flux = 'I', adep_last = year(period_last))
                      %>% left_join(pass_table[,c("year", "nc8", "ctci")], by = c("adep_last" = "year", "nc8")))
            intro <-(intro
                     %>% mutate(ctci=ifelse(conf=="3","93100",ctci),payp = ifelse(conf=="3","QY",payp))
                     %>% group_by(ctci,payp,flux,adep,mdep) 
                     %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "payp"))
            exped <- (mutate(file_exped, adep = year(period), mdep = month(period), flux = 'E', adep_last = year(period_last))
                      %>% left_join(pass_table[,c("year", "nc8", "ctci")], by = c("adep_last" = "year", "nc8")))
            exped <- (exped 
                      %>% mutate(ctci=ifelse(conf=="3","93100",ctci),pyod=ifelse(conf=="3","QY",pyod))
                      %>% group_by(ctci,pyod,flux,adep,mdep) 
                      %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "pyod"))
            result <- rbind(exped, intro) %>% 
              subset(subset = (!(`pyod(exped) / payp(intro)` %in% exclu) & !is.na(`pyod(exped) / payp(intro)`) & (`pyod(exped) / payp(intro)` != "") & 
                                 !(is.na(ctci)) & (ctci != "") & 
                                 !is.na(adep) & (adep != "") & 
                                 !is.na(mdep) & (mdep != "") & 
                                 !is.na(vart)))
            write.csv2(result, filename, row.names = FALSE, na = "")
            return(result)
}

eurostatCTCI_prechiffre <- GetEurostatCTCIFormat(
  file_exped = exped_ventil_rect, 
  file_introd = intro_ventil_rect, 
  filename = file.path(output_directory,
                       sprintf("production_eurostatCTCI_ref%s.csv", 
                               format(date_ref, "%Y%m"))),
  exclu = c()
)


## 3 - productions au format SH2 --------------
GetEurostatSH2Format = function(file_exped, file_introd, filename, exclu){
            result <- rbind(
              mutate(file_exped, adep = year(period), mdep = month(period), flux = 'E', sh2 = ifelse(conf=="3","99",substr(nc8, 1, 2)),pyod=ifelse(conf=="3","QY",pyod))
              %>% group_by(sh2, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "pyod"),
              mutate(file_introd, adep = year(period), mdep = month(period), flux = 'I', sh2 = ifelse(conf=="3","99",substr(nc8, 1, 2)),payp=ifelse(conf=="3","QY",payp))
              %>% group_by(sh2, payp, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "payp")
            )%>% subset(subset = (!(`pyod(exped) / payp(intro)` %in% exclu) & !is.na(`pyod(exped) / payp(intro)`) & (`pyod(exped) / payp(intro)` != "") & 
                                    !(is.na(sh2)) & (sh2 != "") & 
                                    !is.na(adep) & (adep != "") & 
                                    !is.na(mdep) & (mdep != "") & 
                                    !is.na(vart)))
            write.csv2(result, filename, row.names = FALSE, na = "")
            return(result)
          }


eurostatSH2_prechiffre <- GetEurostatSH2Format(
  file_exped = exped_ventil_rect, 
  file_introd = intro_ventil_rect,  
  filename = file.path(output_directory,
                       sprintf("production_eurostatSH2_ref%s.csv", 
                               format(date_ref, "%Y%m"))),
  exclu = c()
)


