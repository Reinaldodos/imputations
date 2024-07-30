options(scipen = 999) 
pacman::p_load(RPostgreSQL,tidyverse,rio,data.table,openxlsx,janitor,xlsx,dbplyr,arrow,duckdb,fs,tidyverse,DBI,plotly,divRmethodo,corrr)
memory.limit(9999999999)

`%notin%` <- Negate(`%in%`)

source("../mes_fonctions.R")

# Extraction des valeurs observées----------------------------------------------

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


table_donnees = data %>%
  filter(adep %in% c("2022","2023","2024"),
         oblig == "1") %>%
  group_by(sire, adep, mdep, imex, regdem) %>%
  summarise(vart = sum(vart, na.rm = T)) %>%
  collect()



table_donnees = table_donnees %>% 
  ungroup() %>%
  mutate(siren = sire,
         flux = ifelse(imex == 3, "intro", "exped"),
         period = make_date(year=adep,month=mdep,1)) %>%
  distinct(siren, period, flux, vart,regdem) 


saveRDS(table_donnees,"analyses/table_donnees.rds")

# table donnees detail

table_nc8 = data %>%
  filter(adep %in% c("2022","2023","2024"),
         oblig == "1") %>%
  group_by(sire, adep, mdep, imex, regdem,payp,pyod,nc8) %>%
  summarise(vart = sum(vart, na.rm = T)) %>%
  collect()

table_nc8 = table_nc8 %>% 
  ungroup() %>%
  mutate(siren = sire,
         flux = ifelse(imex == 3, "intro", "exped"),
         period = make_date(year=adep,month=mdep,1)) %>%
  distinct(siren, period, flux, vart,regdem) 

saveRDS(table_nc8,"analyses/table_nc8.rds")

#-------------------------------------------------------------------------------
table_donnees = readRDS("analyses/table_donnees.rds")

# Lecture de la base historique des imputations --------------------------------
Base_historique <- readRDS("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/historique/Base_historique.rds")
echantillon <- readRDS("Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/échantillon/échantillon_202401/2024_FE_1_1.5_20240612.rds")



Base_historique = Base_historique %>%
  mutate(moisref = make_date(
    year = str_sub(mois_ref, 1, 4),
    month = str_sub(mois_ref, 5, 6),
    day = 1
  )) 



table_imputations = Base_historique %>%
  distinct(siren, period, flux, regdem,prediction, dist_prediction, method, method_ref, source, moisref) %>%
  filter(source == "prechiffre" & moisref <  period + months(3))


# Table des valeurs observées et imputées


table_revert = table_imputations %>% 
  left_join(table_donnees %>% mutate(top=1),by=c("siren","period","flux","regdem")) %>% 
  group_by(siren,period,flux,regdem,moisref) %>% 
  mutate(predit = sum(dist_prediction,na.rm=T)) %>% 
  mutate(time = case_when(moisref == period + months(0) ~"first_estimate",
                          moisref == period + months(1) ~"second_estimate",
                          moisref == period + months(2) ~"third_estimate")) %>% 
  left_join(TB(table_imputations,period,flux,moisref)) %>% rename(champs= n) %>% 
  distinct(siren,period,flux,regdem,prediction,predit,method,source,moisref,vart,top,time,champs)

saveRDS(table_revert,"analyses/table_revert.rds")


# Taux de non réponse par période-----------------------------------------------

nb_echant = data.frame(flux= c("exped","intro"),
         total= c(20770,32250))

TNR = TB(table_revert,period,flux,time) %>% 
  left_join(nb_echant,by="flux") %>% 
  mutate(tnr = 100*(n/total)) %>% filter(period<"2024-02-01")

TNR %>% ggplot( aes(x=period, y=tnr, fill=time)) +
  geom_bar(stat="identity", position=position_dodge())+
  facet_grid(flux ~ .)

# Profilage des taux => qualite et APE, P3


ProfilQ = table_revert %>% 
  left_join(echantillon %>% mutate(echant=1),by="siren") %>% 
  mutate(annee=year(period)) %>% 
  distinct(annee,siren,time,qualite)
voirQ =TB(ProfilQ,annee,qualite) %>% 
  filter(!is.na(qualite)) %>%
  mutate(tot=sum(n),pct=100*n/tot)

voirQ %>% rio::export("analyses/table_Q.xlsx")


ProfilAPE = table_revert %>% 
  left_join(echantillon %>% mutate(echant=1),by="siren") %>% 
  mutate(annee=year(period)) %>% 
  distinct(siren,activitePrincipaleUniteLegale)

voirAPE =TB(ProfilAPE,activitePrincipaleUniteLegale) %>% 
  filter(!is.na(activitePrincipaleUniteLegale)) %>%
  mutate(tot=sum(n),pct=100*n/tot)

voirE=TB(echantillon,activitePrincipaleUniteLegale) %>%
  mutate(tot=sum(n),pct_echant=100*n/tot)

voirAPE = voirAPE %>% left_join(voirE,by="activitePrincipaleUniteLegale") %>% 
  distinct(activitePrincipaleUniteLegale,pct,pct_echant)


voirAPE %>% rio::export("analyses/table_APE.xlsx")
  
# Entreprises à plus 10M

UL10M= table_revert %>% filter(predit>10000000) %>% 
  filter(method %notin% c("reglementation"))


# ratio de réponse par an


table_r = table_donnees %>% 
  group_by(siren,period,flux) %>% 
  summarise(vart = sum(vart, na.rm = T),
   .groups="drop") %>% 
  mutate(annee = year(period)) %>% 
  group_by(siren,annee,flux) %>% 
  mutate(ratio=n()) %>% 
  ungroup()


table_revert = table_revert %>% ungroup() %>% 
  left_join(table_r %>% distinct(siren,period,flux,ratio)) %>% 
  mutate(annee=year(period))
  

table_revert_top = table_revert %>% filter(top==1)



moyenne_ratio = table_revert_top %>% 
  group_by(annee,time,method) %>% 
  summarise(moy=mean(ratio,na.rm=TRUE))
  



table_lastestimate = table_revert_top %>% 
  group_by(siren,period,flux,regdem) %>% 
  mutate(keep = max(moisref,na.rm=T)) %>% 
  filter(moisref==keep)



table_filter = table_revert_top %>% 
  filter( prediction > 0,
          prediction < 10000000,
          vart < 10000000,
          method %notin% c("reglementation"))

table_filter = table_lastestimate %>% 
  filter( prediction > 0,
          prediction < 10000000,
          vart < 10000000,
          method %notin% c("reglementation"))





# Graphique agrégé--------------------------------------------------------------


table_agreg = table_filter %>% 
  mutate(regime = ifelse(regdem %in% c("11","19"),"intro",paste0("exped_",regdem))) %>% 
  group_by(period, flux,regime,time,champs) %>%
  summarise(vart = sum(vart, na.rm = T),
            prediction = round(sum(prediction, na.rm = T)),
            n=n())


diff = table_agreg %>% split(.$regime)


diff %>% openxlsx::write.xlsx("analyses/results.xlsx")



table_agreg %>% filter(flux == "intro") %>%
  group_by(period, time) %>%
  summarise(vart = sum(vart, na.rm = T),
            prediction = sum(prediction, na.rm = T)) %>%
  pivot_longer(c(vart, prediction),
               names_to = "type",
               values_to = "valeur") %>%
  ggplot(aes(x = period, y = valeur, colour = type)) +
  geom_line() +
  geom_point() +
  
  scale_y_continuous(
    breaks = seq(0, 800000000, by = 100000000),
    labels=function(x) format(x, big.mark = " ", scientific = FALSE))+
  ylab("valeur")+ 
  xlab("periode")+
  #scale_x_continuous(labels=labels) +
  facet_grid(time ~ .)+
  ggtitle("Estimations des introductions")




wb <- openxlsx::createWorkbook()

export_graph = function(table,estimate){
  
  mySheet <- addWorksheet(wb, estimate)
  
  viz = table  %>% filter(time == estimate) %>%
    group_by(period, flux) %>%
    summarise(vart = sum(vart, na.rm = T),
              prediction = sum(prediction, na.rm = T)) %>%
    pivot_longer(c(vart, prediction),
                 names_to = "type",
                 values_to = "valeur") %>%
    ggplot(aes(x = period, y = valeur, colour = type)) +
    geom_line() +
    geom_point() +
    # scale_x_continuous(labels=labels) +
    facet_grid(flux ~ .)
  
  print(viz)
  insertPlot(wb, mySheet,  width = 8,
             height = 5) # Will add the current plot
  rm(viz)
}


# labels = seq.Date(as.Date("2022-01-01"),as.Date("2024-01-01"),by="month")

liste = c("first_estimate", 
          "second_estimate", 
          "third_estimate")
liste %>% map(.x = .,
                 .f = export_graph,
                 table = table_filter)
openXL(wb)


export_graph2 = function(table,estimate){
  
  mySheet <- addWorksheet(wb, estimate)
  
  viz = table  %>% mutate(estimate = paste0(time,"_",flux)) %>% 
    filter(estimate==estimate) %>%
    group_by(period, flux) %>%
    summarise(vart = sum(vart, na.rm = T),
              prediction = sum(prediction, na.rm = T)) %>%
    pivot_longer(c(vart, prediction),
                 names_to = "type",
                 values_to = "valeur") %>%
    ggplot(aes(x = period, y = valeur, colour = type)) +
    geom_line() +
    geom_point() 
  
  print(viz)
  insertPlot(wb, mySheet) # Will add the current plot
  rm(viz)
}

liste = c("first_estimate", 
          "second_estimate", 
          "third_estimate")
liste2= c("intro","exped")

metalist =  tidyr::crossing(liste, liste2) %>% mutate(estimate=paste0(liste,"_",liste2))

pmap(
  .l = list(estimate = metalist$liste,
            flux = metalist$liste2),
  .f = export_graph2,
  table = table_filter
)



# Graphiques detaillés -----------------------------------------------------------



wb <- openxlsx::createWorkbook()

export_graph_detail = function(table,estimate,flow){
  mySheet <- addWorksheet(wb, estimate)
  viz = table  %>% filter(time==estimate & period > "2022-12-01" & flux==flow) %>% 
    ggplot(mapping = aes(x = vart, y = predit,colour = method)) +
    geom_point() + geom_abline() + geom_smooth(method = "lm")
  print(viz)
  insertPlot(wb, mySheet) # Will add the current plot
  rm(viz)
}


liste=c("first_estimate","second_estimate","third_estimate")

liste %>% map(.x = .,
              .f=export_graph_detail,
              table = table_filter ,
              flow = "exped")
openXL(wb)




# comptages détaillés ----------------------------------------------------------


Compter= table_revert %>% filter(period > "2022-12-01",
                                 # prediction > 0,
                                 # prediction < 10000000,
                                 method %notin% c("reglementation")) %>% 
  mutate(annee=year(period)) %>% 
  group_by(annee,flux,time,top) %>% 
  summarise(n= n(),vart=sum(vart,na.rm=T),
            predit=sum(predit,na.rm=T),
            pct = round(100*(predit-vart)/vart),
            .groups = "drop") %>% 
  group_by(annee,flux,time) %>% 
  mutate(across(c(n,vart,predit),\(x) sum(x, na.rm = TRUE),.names = "sum_{.col}"),
         pct_n=100*(n/sum_n),pct_predit=100*(predit/sum_predit)
  )
  
Compter_tout= table_revert %>% 
  group_by(year(period),flux,time,top) %>% 
  summarise(n= n(),vart=sum(vart,na.rm=T),
            predit=sum(predit,na.rm=T))


# correlation

table_corr = table_revert_top %>% 
  filter(method %notin% c("reglementation"))


correlation = function(table) {
  
  cor = cor.test(table$prediction,
                 table$vart,
                 method = c("pearson", "kendall", "spearman"))
  return(data.table(
          flux = unique(table$flux),
          time = unique(table$time),
          n = cor$parameter,
          method = unique(table$method),
          estimation = cor$estimate,
          intervalle = cor$conf.int
    )
  )
}

table = table_corr %>% 
  ungroup() %>% 
  filter(period > "2022-12-01") %>% 
  mutate(entree = paste(flux,time,method,sep="_")) %>% 
  # filter(flux == "intro",
  #        time == "first_estimate") %>% 
  split(.$entree) %>% 
  map( ~ correlation(.)) %>% bind_rows() %>% 
  group_by(flux,time,method,n) %>%
  mutate(type = paste0("intervalle_",1:n())) %>%
  pivot_wider(.,names_from = type,values_from = intervalle) %>%
  unique()


# exporter la table


table %>% rio::export("analyses/table_correlation.xlsx")



# produire les graph

grapher = function(table, estimate,flux){
  
  liste_graph = table %>% 
    filter(time == estimate & flux == flux ) %>%
    group_by(period, flux) %>%
    summarise(vart = sum(vart, na.rm = T),
              prediction = sum(prediction, na.rm = T)) %>%
    pivot_longer(c(vart, prediction),
                 names_to = "type",
                 values_to = "valeur") %>%
    ggplot(aes(x = period, y = valeur, colour = type)) +
    geom_line() +
    geom_point() 
  # names(liste_graph) = paste0(estimate,"_",flux)
  return(liste_graph)
  
}


liste = c("first_estimate", 
          "second_estimate", 
          "third_estimate")
liste2= c("intro","exped")

metalist =  tidyr::crossing(liste, liste2) %>% mutate(estimate=paste0(liste,"_",liste2))
name_liste = metalist$estimate 

liste_graph=pmap(
  .l = list(estimate = metalist$liste,
            flux = metalist$liste2),
  .f = grapher,
  table = table_filter
)
names(liste_graph)=name_liste
name_liste = name_liste %>% as.list() %>% flatten()
names(liste_graph$first_estimate_exped)

wb <- openxlsx::createWorkbook()
export_graph = function(graph,name){
    mySheet <- addWorksheet(wb, name)
    
    print(graph)
    insertPlot(wb, mySheet) # Will add the current plot

  }

liste_graph=pmap(
  .l = list(graph = liste_graph,
            name = name_liste),
  .f = export_graph
)

openXL(wb)



# Analyse A129 * pays ----------------------------------------------------------

A129 = table_revert_top %>% group_by(annee,)

