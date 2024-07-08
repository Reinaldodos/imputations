pacman::p_load(tidyverse,dbplyr)

fichier_config <-
  file.path("Z:",
            "DG_STAT_prive",
            "1_ETUDES et METHODES",
            "R",
            "Liste credentials.yml")
utilisateur <- "Léa"


my_bdd <- 
  divRmethodo::connexion_base_etudes(
    fichier_config = fichier_config,
    utilisateur = utilisateur
  )


# lecture lazy
data <- tbl(my_bdd, in_schema("sc_astrineo", "florea"))

debut = as.Date("2023-01-01")
fin = as.Date("2024-04-01")

# type = c(
#   "intro_imput",
#   "intro_ventil",
#   "exped_imput",
#   "exped_ventil",
#   "ER_exped",
#   "vin-spiritueux"
# ),
# start = c(
#   date_ref - months(48),
#   date_ref - months(24),
#   date_ref - months(48),
#   date_ref - months(24),
#   date_ref - months(2),
#   date_ref - months(12)
# ),
# end = date_ref) 

GroupFiltreSum <- function(data,
                            grouping_var,
                            column_name,
                            type,
                            td,
                            flux,
                            annee,
                            liste_mois,
                            cniv) {
  
  if(cniv == TRUE){
  data = data %>% filter(str_sub(nc8,1,4) %in% c("2204","2208"))
  }
  else{
  data = data
  }
    
  table = data %>%
    filter(adep %in% annee,
           imex %in% flux,
           oblig %in% type,
           vaco %in% td,
           sire == "531597128") %>% 
    group_by(
    across({{grouping_var}})) %>%  
    summarise(across({{column_name }}, \(x) sum(x, na.rm = TRUE))) %>% 
    collect()
  
  return(table)
}


# test = groupFiltre_sum(
#   data = data,
#   grouping_var = c("sire", "adep", "mdep", "imex","regdem","oblig","vaco"),
#   column_name = c("vart","vfte"),
#   type = c("1","4"),
#   flux = c("3","4"),
#   td = c("1","3"),
#   annee = period,
#   cniv = TRUE
# )


RequeteParams = function(debut, fin) {
  ER_exped = list(
    grouping_var = c("sire", "adep", "mdep", "regdem"),
    column_name = c("vart", "vfte"),
    type = c("4"),
    flux = c("4"),
    td = c("0"),
    annee = as.character(year(seq(debut, fin, by = "year"))),
    cniv=FALSE
  )
  exped_imput = list(
    grouping_var = c("sire", "adep", "mdep","regdem"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("4"),
    td = c("1", "3"),
    annee = c("2024", "2023"),
    cniv=FALSE
  )
  exped_ventil = list(
    grouping_var = c( "sire", "adep", "mdep", "a129", "nc8", "payp", "pyod", "dept", "regdem", "temo", "natr", "conf"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("4"),
    td = c("1", "3"),
    annee = c("2024", "2023"),
    cniv=FALSE
  )
  intro_imput = list(
    grouping_var = c("sire", "adep", "mdep"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("3"),
    td = c("1", "3"),
    annee = c("2024", "2023"),
    cniv=FALSE
  )
  intro_ventil = list(
    grouping_var = c( "sire", "adep", "mdep", "a129", "nc8", "payp", "pyod", "dept", "regdem", "temo", "natr", "conf"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("3"),
    td = c("1", "3"),
    annee = c("2024", "2023"),
    cniv=FALSE
  )
  vin_spiritueux = list(
    grouping_var = c( "sire", "adep", "mdep", "ngp", "nc8"),
    column_name = c("vart","usup"),
    type = c("1","4"),
    flux = c("1","2","3","4"),
    td = c("1", "3"),
    annee = c("2024", "2023"),
    cniv = TRUE
  )
  
 
  meta_liste = list(ER_exped = ER_exped, 
                    exped_imput = exped_imput,
                    exped_ventil = exped_ventil,
                    intro_imput = intro_imput,
                    intro_ventil = intro_ventil,
                    vin_spiritueux = vin_spiritueux)
  return (meta_liste)
}

liste_requete = RequeteParams(debut = debut, fin = fin)

mes_requetes = liste_requete %>% 
  map( ~ GroupFiltreSum(
           annee = .$annee,
           flux = .$flux,
           type = .$type,
           grouping_var = .$grouping_var,
           column_name = .$column_var,
           td = .$td,
           cniv = .$cniv,
    data = data)) 





cible_test = echantillon %>% filter(siren %in% c("056802218","056806813","056807290","056809957")) %>% distinct(siren)


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
  agg_var <- dict$agg_var %>% str_split(", ") %>% flatten_chr()
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




liste_fichiers <- data.frame(
  type = c(
    "intro_imput",
    "intro_ventil",
    "exped_imput",
    "exped_ventil",
    "ER_exped",
    "vin-spiritueux"
  ),
  start = c(
    date_ref - months(48),
    date_ref - months(24),
    date_ref - months(48),
    date_ref - months(24),
    date_ref - months(2),
    date_ref - months(12)
  ),
  end = date_ref) %>% 
  rowwise() %>% mutate(command =
  map( .,.f= WriteCommand(start, end, (str_split(type, "_20") %>% flatten_chr())[1])))
  
