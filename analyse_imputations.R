options(scipen = 999) 
pacman::p_load(RPostgreSQL,tidyverse,rio,data.table,openxlsx,janitor,lubridate,gtools,xlsx,dbplyr,arrow,duckdb,fs,tidyverse,DBI,glue)
memory.limit(9999999999)

`%notin%` <- Negate(`%in%`)

Base_historique <- readRDS("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/historique/Base_historique.rds")

Base_1jet = Base_historique %>%
  filter(source == "chiffre") %>%
  filter(paste0(str_sub(period, 1, 4),
                str_sub(period, 6, 7)) == mois_ref)


echantillon = readRDS("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/échantillon/échantillon_202401/2024_FE_0_1.4_20240423.rds")


fichier_config = 
  file.path("Z:",
            "DG_STAT_prive",
            "1_ETUDES et METHODES",
            "R",
            "Connexion base etudes.yml")

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

#Attention ajouter un round/ regarder les NA aussi
Base_pred = Base_1jet %>%  ungroup() %>% 
  distinct(siren, method,period, prediction, flux) %>%
  group_by(siren,period,flux) %>% mutate(n=n())
  filter( str_sub(period, 1, 4) == "2023" &
    method %notin% c("reglementation")) %>%
  mutate(mdep = str_sub(period, 6, 7))

 
  
  
tb = Base_pred %>% ungroup() %>%  group_by(siren, mdep, flux,method) %>% mutate(n=n()) 
  
  
  
  
  filter(prediction > 0,
         prediction < 10000000)


Base_dist = Base_1jet %>% ungroup() %>% 
  filter(str_sub(period, 1, 4) == "2023" & method %notin% c("reglementation")) %>%
  mutate(mdep = str_sub(period, 6, 7)) %>%
  group_by(siren, mdep, flux) %>% 
  mutate(prediction = sum(dist_prediction, na.rm = T)) %>%
  distinct(siren, mdep, prediction, flux, method) %>% 
  filter(prediction > 0,
         prediction < 10000000)
  


table_2023 = table_2023 %>% 
  ungroup() %>%
  mutate(siren = sire,
         flux = ifelse(imex == 3, "intro", "exped")) %>%
  distinct(siren, mdep, flux, vart) 

# liste_2023 = Base_1jet02 %>% inner_join(fevrier,by = c("siren", "mdep", "flux")) %>% 
#   mutate(ecart=100*((vart-prediction)/vart)) 
# 
# sqrt(mean((liste_2023$vart - liste_2023$prediction)^2))


list("prediction" = Base_1jet02,
     "valeur" = table_2023) %>%
  reduce(.f = inner_join, by = c("siren", "mdep", "flux")) %>%
  ggplot(mapping = aes(x = prediction, y = vart)) +
  geom_point() + geom_abline() + geom_smooth(method = "lm") +
  facet_grid(method ~ .)


