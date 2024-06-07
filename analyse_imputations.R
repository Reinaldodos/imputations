options(scipen = 999) 
pacman::p_load(RPostgreSQL,tidyverse,rio,data.table,openxlsx,janitor,xlsx,dbplyr,arrow,duckdb,fs,tidyverse,DBI,plotly,divRmethodo)
memory.limit(9999999999)

`%notin%` <- Negate(`%in%`)

source("../mes_fonctions.R")


Base_historique <- readRDS("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/historique/Base_historique.rds")


Base_historique = Base_historique %>%
  mutate(moisref = make_date(
    year = str_sub(mois_ref, 1, 4),
    month = str_sub(mois_ref, 5, 6),
    day = 1
  ))


# filter_ref = function(type,pas){
#   table = Base_historique %>% 
#     filter(source == type) %>%
#     filter(moisref == period + pas)
#   return(table)
#   
# }
# pas =months(1)
# Base_1jet = filter_ref(type = "prechiffre", pas = months(0))
# Base_2jet = filter_ref(type = "prechiffre", pas = months(1))
# Base_3jet = filter_ref(type = "prechiffre", pas = months(2))


test = Base_historique %>% distinct(siren,period,flux,prediction,method,source,moisref) %>% 
  filter(  source=="prechiffre" & moisref <  period + months(3))


table = table_2023 %>% 
  inner_join(test,by=c("siren","period","flux")) %>% 
  mutate(time = case_when(moisref == period + months(0) ~"first_estimate",
                          moisref == period + months(1) ~"second_estimate",
                          moisref == period + months(2) ~"third_estimate")) %>% 
  filter( prediction > 0,
          prediction < 1000000,
          vart < 1000000,
          method %notin% c("reglementation"))




liste = c()

list_decile = sprintf("D%02d", 1:10) 
liste_enquete = c("intro", "exped", "intro+exped")
liste_mode = c("DTI", "DTI+")

meta_liste = tidyr::crossing(list_decile, liste_enquete, liste_mode)



fichier_config = 
  file.path("Z:",
            "DG_STAT_prive",
            "1_ETUDES et METHODES",
            "R",
            "Liste credentials.yml")

utilisateur = "Léa"


my_bdd <- 
  divRmethodo::connexion_base_etudes(
    fichier_config = fichier_config,
    utilisateur = utilisateur
  )

# lecture lazy
data <- tbl(my_bdd, in_schema("sc_astrineo", "florea"))


table_2023 = data %>%
  filter(adep == "2023",
         oblig == "1") %>%
  group_by(sire, adep, mdep, imex) %>%
  summarise(vart = sum(vart, na.rm = T)) %>%
  collect()


table_2023 = table_2023 %>% 
  ungroup() %>%
  mutate(siren = sire,
         flux = ifelse(imex == 3, "intro", "exped"),
         period = make_date(year=adep,month=mdep,1)) %>%
  distinct(siren, period, flux, vart) 

#Attention ajouter un round/ regarder les NA aussi
Base_pred = Base_2jet %>%  
  select(-adep,-mdep) %>% 
  mutate(adep = str_sub(period, 1, 4),
         mdep = str_sub(period, 6, 7),
         prediction = round(prediction,0)) %>% 
  filter(adep == "2023" & method %notin% c("reglementation"))

prediction = Base_pred %>% 
  distinct(siren,adep,mdep, method,period, prediction, flux) %>% 
  filter(prediction > 0,
         prediction < 10000000)

Base_dist = Base_pred %>% 
  group_by(siren, mdep, flux) %>% 
  mutate(prediction = sum(dist_prediction, na.rm = T)) %>%
  distinct(siren, mdep, prediction, flux, method) %>% 
  filter(prediction > 0,
         prediction < 10000000)
  



table_2023_filter = table_2023 %>%
  filter(vart > 0,
         vart < 10000000)

# liste_2023 = Base_1jet02 %>% inner_join(fevrier,by = c("siren", "mdep", "flux")) %>% 
#   mutate(ecart=100*((vart-prediction)/vart)) 
# 
# sqrt(mean((liste_2023$vart - liste_2023$prediction)^2))


list("prediction" = prediction,
     "valeur" = table_2023_filter) %>%
  reduce(.f = inner_join, by = c("siren", "mdep", "flux")) %>%
  ggplot(mapping = aes(x = vart, y = prediction)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm")





wb <- openxlsx::createWorkbook()

export_graph = function(table,estimate){
mySheet <- addWorksheet(wb, estimate)
viz = table  %>% filter(time==estimate) %>% 
  ggplot(mapping = aes(x = vart, y = prediction,colour = method)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm") 
print(viz)
insertPlot(wb, mySheet) # Will add the current plot
rm(viz)
}


liste=c("first_estimate","second_estimate","third_estimate")

liste %>% map(.x = .,
              .f=export_graph,
              table = table)
openXL(wb)

export_graph( table = table, estimate = "third_estimate" )

voir = table %>% filter(time =="third_estimate")

voir %>% ggplot(mapping = aes(x = vart, y = prediction)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm") 
liste_graph %>% 
openxlsx::write.xlsx(file = "../tableaux frequence.xlsx")

viz = list("prediction" = prediction,
     "valeur" = table_2023_filter) %>%
  reduce(.f = inner_join, by = c("siren", "mdep", "flux")) %>%
 ggplot(mapping = aes(x = vart, y = prediction)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm") +
  facet_grid(method ~ .)
viz
ggplotly(viz)

list("prediction" = Base_dist,
     "valeur" = table_2023) %>%
  reduce(.f = inner_join, by = c("siren", "mdep", "flux")) %>%
  ggplot(mapping = aes(x = prediction, y = vart)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm") +
  facet_grid(method ~ .)
