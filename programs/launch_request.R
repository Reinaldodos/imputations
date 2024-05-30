pacman::p_load(tidyverse,dbplyr)

fichier_config <-
  file.path("Z:",
            "DG_STAT_prive",
            "1_ETUDES et METHODES",
            "R",
            "Connexion base etudes.yml")
utilisateur <- "Léa"


my_bdd <- 
  divRmethodo::connexion_base_etudes(
    fichier_config = fichier_config,
    utilisateur = utilisateur
  )


# lecture lazy
data <- tbl(my_bdd, in_schema("sc_astrineo", "florea"))

debut = "2024-01-01"
fin="2024-01-01"
FilterPeriod_Sum= function(data,debut,fin,var,...){

  periode <- seq.Date(from = as.Date(debut), to = as.Date(fin), by = 'month') %>%
  as_tibble() %>%
  mutate(adep = format(value, "%Y"),
         mdep = format(value, "%m")) %>% 
  as.data.frame()
  
  annee = c(unique(periode$adep))
  mois = c(unique(periode$mdep))
  
  var = sym(var)
  # filtre = sym(filtre)
  
  table = data %>%
      filter(sire == "056802218" ) %>% 
      # filter({{filtre}}) %>% 
      filter(adep %in% annee,
             mdep %in% mois) %>%
      # semi_join(periode %>% distinct(adep,mdep),by=c("adep","mdep")) %>% 
      group_by(sire,adep,mdep,imex,...) %>%
      summarise(
          across(.cols = {{var}},
                 .fns = ~ sum(., na.rm = TRUE)
          ),
          .groups = "drop") %>% 
    collect()
    

  return(table)
}


cible_test = echantillon %>% filter(siren %in% c("056802218","056806813","056807290","056809957")) %>% distinct(siren)

ER = FilterPeriod_Sum(data = data,
                       debut = request$start,
                       fin=request$end
                       # var = request$var,
                       # filtre = request$filtre
                        )
                       # # ecrire le filtre
                       # oblig = '1' & vaco %in% c('1', '3'))
                      # ecrire les variables de groupement
                       sire,
                       adep,
                       mdep)
                       

ER = FilterPeriod_Sum(data = data,
                      debut = request$start,
                      fin=request$end,
                      var = request$var)
                      # filtre = request$filtre)


request=request_data %>% filter(names=="ER_exped")
request_data = data.frame(
  names = c("imput", "ventil", "ER_exped", "vin-spiritueux"),
  # start = c("2020-04-01", "2021-04-01","2022-01-01","2021-01-01"),
  start = c("2024-03-01", "2024-03-01","2024-03-01","2024-03-01"),
  end = date_ref,
  filtre= c("oblig == '1' , vaco %in% c('1', '3')",
    "oblig == '1',vaco %in% c('1', '3')",
    "oblig == '4',regdem == '21'",
    "str_sub(nc8,1,4) %in% c('2204','2208'), vaco %in% c('1', '3')"),
  var = c("vart","vart","c('vart','vfte')","vart,usup")
)




dict <- data.frame(
  type = c("intro_imput", "intro_ventil", "exped_imput", "exped_ventil", "ER_exped", "vin-spiritueux"), 
  var = c("sire, adep, mdep", 
          "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
          "sire, adep, mdep, regdem", 
          "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
          "sire, adep, mdep, regdem", 
          "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end flux"),
  var_group_by = c("sire, adep, mdep", 
                   "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                   "sire, adep, mdep, regdem", 
                   "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                   "sire, adep, mdep, regdem", 
                   "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end"),
  agg_var = c("vart", "vart", "vart", "vart", "vart, vfte", 
              "vart, usup") 
) %>%
  mutate(condition = case_when(
    (grepl(pattern = "intro", x = type)) ~ "(imex = '3') and (oblig = '1') and (vaco in ('1', '3'))", 
    (grepl(pattern = "imput", x = type) | grepl(pattern = "ventil", x = type)) ~ "(imex = '4') and (oblig = '1') and (vaco in ('1', '3'))", 
    (grepl(pattern = "ER", x = type)) ~ "(oblig = '4') and (regdem = '21')", 
    TRUE ~ "((nc8 like '2204%') or (nc8 like '2208%')) and (vaco in ('1','3'))"
    

dta = data %>%
  filter (sire %in% cible_liste,
          adep=="2024",
          mdep %in% v) %>% 
  group_by(sire,adep, mdep) %>%
  summarise(n = sum(vart, na.rm = T)) %>%
  collect()


echantillon = sample %>% filter(date_beg=="2024-01-01")
delete = delete %>% filter(!(is.na(siren_repreneur)))

cible = echantillon %>% distinct(siren) %>% 
  bind_rows(delete %>% distinct(siren)) %>% 
  bind_rows(delete %>% distinct(siren=siren_repreneur)) %>% unique()

cible_liste = c(unique(cible$siren))





start_time=Sys.time()
dta = data %>%
  filter (sire %in% cible_liste,
          adep=="2024",
          mdep %in% v) %>% 
  group_by(sire,adep, mdep) %>%
  summarise(n = sum(vart, na.rm = T)) %>%
  collect()
print(Sys.time() - start_time)



cible_test = echantillon %>% filter(siren %in% c("056802218","056806813","056807290","056809957")) %>% distinct(siren)

# cible = echantillon %>% distinct(siren) %>% 
#   left_join(delete,by="siren") %>% 
#   mutate(siren_new = ifelse(test = is.na(siren_repreneur),
#                           yes = siren,
#                           no = siren_repreneur)







#ajouter la jointure periode, puis filter

groupFiltre_sum= function(data,...,debut,fin){
  table = data %>% filter(period >= debut, period <= fin ) %>% 
    group_by(...) %>% summarise(n=sum(vart,na.rm=T)) %>% 
    collect()
  return(table)
}




liste = seq.Date(
  from = as.Date("2024-01-01"),
  to = as.Date("2024-12-01"),
  by = "1 month"
) %>% as.data.frame() %>% 
  setNames("period") %>% 
  mutate(adep = as.character(year(period)),
         mdep = sprintf("%02d",month(period)))

liste %>%
  group_by(adep) %>%
  summarise(mdep = paste(mdep, collapse = ", ")) %>%
  ungroup()


start_time=Sys.time()
data_echantillon = data %>%
  inner_join(cible_test, by = c("sire" = "siren"), copy = T) %>% 
  inner_join(liste, by = c("adep","mdep"), copy = T) %>%
  group_by(sire,adep, mdep) %>%
  summarise(n = sum(vart, na.rm = T)) %>%
  show_query()
print(Sys.time() - start_time)


start_time=Sys.time()
data_echantillon = data %>%
  inner_join(cible_test, by = c("sire" = "siren"), copy = T) %>% 
  inner_join(liste, by = c("adep","mdep"), copy = T) %>%
  group_by(sire,adep, mdep) %>%
  summarise(n = sum(vart, na.rm = T)) %>%
  show_query()
print(Sys.time() - start_time)
v=c(unique(liste$mdep))
w=c(unique(cible_test$siren))

start_time=Sys.time()
  dta = data %>%
    filter (sire %in% w,
            adep=="2024",
            mdep %in% v) %>% 
    group_by(sire,adep, mdep) %>%
    summarise(n = sum(vart, na.rm = T)) %>%
    collect()
print(Sys.time() - start_time)
  

data <- dbGetQuery(conn = connexion, statement = sql(request_data[irow,]$command))



  
start= as.Date()
fin="2024-02-01"

import_imput = FilterPeriod_Sum(data = data_echantillon,
                       adep,
                       mdep,
                       debut = start,
                       fin = end)





unregister_dopar <- function() {
  env <- foreach:::.foreachGlobals
  rm(list=ls(name=env), pos=env)
}

WriteCommand <- function(from, to, type){
  period <- seq.Date(from = from, to = to, by = 'month') %>%
    as_tibble() %>%
    mutate(adep = format(value, "%Y"), 
           mdep = format(value, "%m")) %>%
    group_by(adep) %>%
    mutate(month_command = sprintf("mdep in (%s)", paste("'", mdep, "'", collapse = ", ", sep = ""))) %>%
    ungroup() %>%
    group_by(month_command) %>%
    summarise(command = sprintf("((adep in (%s)) and (%s))", 
                                paste("'", unique(adep), "'", collapse = ", ", sep = ""), 
                                month_command)) %>%
    ungroup() %>%
    select(command) %>%
    unique() %>%
    flatten_chr() %>%
    paste("(", ., ")", collapse = " or ", sep = "")
  
  dict <- data.frame(
    type = c("intro_imput", "intro_ventil", "exped_imput", "exped_ventil", "ER_exped", "vin-spiritueux"), 
    var = c("sire, adep, mdep", 
            "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
            "sire, adep, mdep, regdem", 
            "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
            "sire, adep, mdep, regdem", 
            "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end flux"),
    var_group_by = c("sire, adep, mdep", 
                     "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                     "sire, adep, mdep, regdem", 
                     "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                     "sire, adep, mdep, regdem", 
                     "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end"),
    agg_var = c("vart", "vart", "vart", "vart", "vart, vfte", 
                "vart, usup") 
  ) %>%
    mutate(condition = case_when(
      (grepl(pattern = "intro", x = type)) ~ "(imex = '3') and (oblig = '1') and (vaco in ('1', '3'))", 
      (grepl(pattern = "imput", x = type) | grepl(pattern = "ventil", x = type)) ~ "(imex = '4') and (oblig = '1') and (vaco in ('1', '3'))", 
      (grepl(pattern = "ER", x = type)) ~ "(oblig = '4') and (regdem = '21')", 
      TRUE ~ "((nc8 like '2204%') or (nc8 like '2208%')) and (vaco in ('1','3'))"
    ))
  var <- dict[dict$type == type,]$var
  var_group_by <- dict[dict$type == type,]$var_group_by
  agg_var <- dict[dict$type == type,]$agg_var %>% str_split(", ") %>% flatten_chr()
  condition <- dict[dict$type == type,]$condition
  command <- sprintf(
    "select %s, %s from sc_astrineo.florea where ((%s) and %s) group by %s", 
    var, 
    paste(sprintf("sum(%s) %s", agg_var, agg_var), collapse = ", "), 
    period, 
    condition, 
    var_group_by
  )
  return(command)
}

request_data <-  bind_rows(
  intro_imput_file %>%
    subset(subset = !historical, select = -c(historical, astrineo_input, skiprows, encoding, dec)), 
  exped_imput_file %>%
    subset(subset = !historical, select = -c(historical, astrineo_input, skiprows, encoding, dec)), 
  intro_ventil_file %>% select(-astrineo_input, skiprows, encoding, dec), 
  exped_ventil_file %>% select(-astrineo_input, skiprows, encoding, dec),
  ER_file %>% select(-c(skiprows, encoding, dec)), 
  cniv_file %>% subset(subset = (type == "input"), select = c(directory, files, start, end))
) %>% 
  rowwise() %>%
  mutate(
  command = WriteCommand(start, end, (str_split(files, "_20") %>% flatten_chr())[1])
) %>%
  ungroup()

cl <- makeCluster(5, outfile = 'output.txt')
registerDoParallel(cl)
start_time <- Sys.time()
foreach(irow = 1:nrow(request_data), 
        .packages = c('dplyr', 'RPostgreSQL')) %dopar% 
  {
    connexion <- dbConnect(PostgreSQL(), dbname = "db_etudes", port = 5440,
                           host="dxproetudba01.adm.dnsce.douane",
                           user = user, password = pwd)
    file_name <- file.path(request_data[irow,]$directory, 
                           request_data[irow,]$files)
    data <- dbGetQuery(conn = connexion, statement = sql(request_data[irow,]$command))
    if (grepl(pattern = "vin-spiritueux", x = request_data[irow,]$files)){
      data <- data %>% 
        group_by(sire, adep, mdep, ngp, nc8, imex) %>%
        mutate(vart_e = sum(vart[flux == "E"]), 
               vart_i = sum(vart[flux == "I"]), 
               usup_e = sum(usup[flux == "E"]), 
               usup_i = sum(usup[flux == "I"])) %>%
        ungroup() %>%
        select(-vart, -usup)
    }
    dbDisconnect(connexion)
    write.csv2(data,
               file = file_name,
               row.names = F, 
               quote = F, 
               na = "")
  }
stopCluster(cl)
print(Sys.time() - start_time)
unregister_dopar()






liste_var = c(str_c("sh", 2 * 1:3), "nc8", "natr", "temo", "pyod") 
liste_val = c("value", "value_MDE", "DELTA", "ratio")

output %>% 
  group_sum_pivot(var = "sh2", 
                  val = "DELTA")
  

BASE = 
  crossing(liste_val, liste_var) %>% 
  mutate(
    sortie = pmap(.l = list(var = liste_var,
                            val = liste_val),
                  .f = group_sum_pivot,
                  data = output, 
                  .progress = TRUE)
         )


  
liste_val %>%
  walk(.f = write_fichier,
       input = BASE,
       .progress = TRUE)




