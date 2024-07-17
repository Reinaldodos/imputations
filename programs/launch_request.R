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

# fonction requete
GroupFiltreSum <- function(data,
                           fichier,
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
           sire %in% c("056802218") #pour test ,"056806813","056807290","056809957","531597128"
           ) %>% 
    group_by(
    across({{grouping_var}})) %>%  
    summarise(across({{column_name }}, \(x) sum(x, na.rm = TRUE)), 
              .groups = "drop") %>% 
    rename(siren = sire) %>% 
    collect()
  
  # saveRDS(table,paste0(fichier,".rds")) #enregistrer ou pas, dans ETL ?
  
  return(table)
}

# Parmètres des requetes
RequeteParams = function(date_ref) {
  ER_exped = list(
    fichier = "ER_exped",
    grouping_var = c("sire", "adep", "mdep", "regdem"),
    column_name = c("vart", "vfte"),
    type = c("4"),
    flux = c("4"),
    td = c("0"),
    annee = as.character(year(seq(date_ref - months(2), date_ref, by = "year"))),
    cniv=FALSE
  )
  exped_imput = list(
    fichier = "exped_imput",
    grouping_var = c("sire", "adep", "mdep","regdem"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("4"),
    td = c("1", "3"),
    annee = as.character(year(seq(date_ref - months(48), date_ref, by = "year"))),
    cniv=FALSE
  )
  exped_ventil = list(
    fichier = "exped_ventil",
    grouping_var = c( "sire", "adep", "mdep", "a129", "nc8", "payp", "pyod", "dept", "regdem", "temo", "natr", "conf"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("4"),
    td = c("1", "3"),
    annee = as.character(year(seq(date_ref - months(24), date_ref, by = "year"))),
    cniv=FALSE
  )
  intro_imput = list(
    fichier = "intro_imput",
    grouping_var = c("sire", "adep", "mdep"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("3"),
    td = c("1", "3"),
    annee = as.character(year(seq(date_ref - months(48), date_ref, by = "year"))),
    cniv=FALSE
  )
  intro_ventil = list(
    fichier = "intro_ventil",
    grouping_var = c( "sire", "adep", "mdep", "a129", "nc8", "payp", "pyod", "dept", "regdem", "temo", "natr", "conf"),
    column_name = c("vart"),
    type = c("1"),
    flux = c("3"),
    td = c("1", "3"),
    annee = as.character(year(seq(date_ref - months(24), date_ref, by = "year"))),
    cniv=FALSE
  )
  vin_spiritueux = list(
    fichier = "vin_spiritueux",
    grouping_var = c( "sire", "adep", "mdep", "ngp", "nc8"),
    column_name = c("vart","usup"),
    type = c("1","4"),
    flux = c("1","2","3","4"),
    td = c("1", "3"),
    annee = as.character(year(seq(date_ref - months(12), date_ref, by = "year"))),
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

# Lancer à partir de la date de référence
date_ref= as.Date("2024-04-01")
liste_requete = RequeteParams(date_ref = date_ref)

start = Sys.time()
mes_requetes = liste_requete %>% 
  map( ~ GroupFiltreSum(
           fichier = .$fichier,
           annee = .$annee,
           flux = .$flux,
           type = .$type,
           grouping_var = .$grouping_var,
           column_name = .$column_var,
           td = .$td,
           cniv = .$cniv,
    data = data)) 
Sys.time() - start
list2env(mes_requetes, envir = .GlobalEnv)

