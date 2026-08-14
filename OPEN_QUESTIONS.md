# Phase 5 ter — Questions ouvertes après décision de baseline

## 1. Périmètre de compatibilité

**Décision humaine actée :** `main.R` est la baseline officielle à migrer. Le
comportement de référence est le chemin actif statiquement atteignable depuis
`main.R`.

Le périmètre de compatibilité comprend :

- `config.R` ;
- `programs/Production.R` et `programs/CNIV.R` lorsqu'ils sont chargés par
  `main.R` ;
- la préparation ETL conditionnelle ;
- la préparation pipeline conditionnelle ;
- les chaînes introduction et expédition ;
- les contrôles PC ;
- le traitement CNIV ;
- les fonctions et dépendances effectivement atteignables depuis ces étapes.

Les scripts non atteignables depuis `main.R` sont hors périmètre de
compatibilité, sauf découverte ultérieure d'une dépendance active. Leur usage
éventuel, leur statut historique et leurs secrets restent des sujets
opérationnels ou de sécurité, mais ne constituent plus des blockers de
caractérisation ou de migration de la baseline.

États utilisés :

- **RÉSOLU STATIQUEMENT** : établi par le dépôt ;
- **PARTIELLEMENT RÉSOLU** : le comportement du chemin `main.R` est établi,
  mais une règle opérationnelle ou métier externe reste ouverte ;
- **À POSER À UN HUMAIN** : décision absente du dépôt et nécessaire pour fermer
  le contrat fonctionnel ou opérationnel.

## 2. Synthèse des criticités

### BLOCKER

- `OQ-03` — validité et invalidation des caches actifs ;
- `OQ-12` — règle de ventilation du résultat expédition incluant le régime 29 ;
- `OQ-13` — intention métier de l'utilisation de `vart_21` ;
- `OQ-16` — statut contractuel des artefacts lus par le chemin actif.

Ces questions peuvent modifier les résultats de référence ou empêcher de
préserver le comportement observable de `main.R`.

### IMPORTANT

- `OQ-02` — dépendances S4 encore atteignables ;
- `OQ-06` — chemins et environnement d'inputs actifs ;
- `OQ-11` — provenance et version des inputs ;
- `OQ-14` — outputs contractuels et usages aval ;
- `OQ-15` — cas limites des ratios de ventilation ;
- `OQ-17` — intégrité des dossiers ETL/pipeline ;
- `OQ-18` — versions R/packages validées ;
- `OQ-21` — validation aval des contrôles et sorties CNIV.

### SECONDARY

- `OQ-01` — ordonnancement externe, une fois `main.R` confirmé ;
- `OQ-05` — relances partielles et ordre opérationnel ;
- `OQ-07` — documentation de publication externe ;
- `OQ-20` — volumes et contraintes de charge.

Les questions `OQ-04`, `OQ-08`, `OQ-09`, `OQ-10` et `OQ-19` sont fermées pour
la compatibilité : elles concernent des scripts non atteignables depuis la
baseline. `launch_request.R` conserve un signalement de sécurité hors
périmètre fonctionnel, sans blocker de migration.

## 3. Questions restantes

### OQ-01 — Ordonnancement externe

- **ID** : OQ-01
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Existe-t-il un ordonnanceur externe ou une procédure manuelle
  qui lance `main.R` avec des conditions particulières ?
- **SOURCE** : `main.R:4-169` ; ancienne question `AS_IS.md:350-352`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : `main.R` est officiellement confirmé comme
  baseline. Son ordre interne est observable ; aucun ordonnanceur externe n'est
  présent dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Existe-t-il des contraintes
  externes de lancement de `main.R` qui ne sont pas nécessaires à l'exécution
  complète du chemin baseline ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : aucun impact sur la règle métier du
  chemin complet ; possible complément documentaire d'exploitation.
- **IMPACT — TESTS DE CARACTÉRISATION** : aucun impact sur les tests du chemin
  complet ; impact éventuel sur les tests de lancement.
- **IMPACT — ARCHITECTURE TO-BE** : aucun blocage fonctionnel ; les interfaces
  avec l'ordonnanceur restent hors dépôt.
- **IMPACT — PLAN DE MIGRATION** : peut affecter le déploiement, pas la
  migration du comportement baseline.

### OQ-02 — Dépendances S4 encore atteignables

- **ID** : OQ-02
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelles méthodes S4 atteignables depuis `main.R` sont encore
  nécessaires dans les scénarios actifs ?
- **SOURCE** : `main.R:4-169` ; `programs/Input.R:270-862` ;
  `programs/NR.R:1202-1218,1272-1274` ; `programs/launch_cniv.R:9-22` ;
  `Refactoring/prep pipeline.R:5-87`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : le chemin baseline atteint `Input.R`, `NR.R`,
  `launch_cniv.R` et, conditionnellement, les fonctions `Refactoring/`. Les
  appels historiques atteignables sont identifiés ; leur nécessité dans tous
  les états de fichiers ne l'est pas.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Parmi les méthodes S4 appelées par
  le chemin `main.R`, lesquelles sont contractuellement supportées dans les
  relances et lesquelles ne servent qu'à une branche conditionnelle ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : certaines étapes d'import ou de reprise
  peuvent avoir plusieurs comportements actifs.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faut couvrir les méthodes S4
  atteignables dans les branches réellement supportées.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces fonctionnelles à préserver
  ne sont pas entièrement fermées.
- **IMPACT — PLAN DE MIGRATION** : risque de retirer une dépendance active de
  `Input`, `NR` ou CNIV.

### OQ-03 — Fraîcheur et invalidation des caches actifs

- **ID** : OQ-03
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quelle règle détermine qu'un cache actif de `main.R` est valide
  ou doit être reconstruit ?
- **SOURCE** : `main.R:20-26,88-94` ; `programs/NR.R:953-974,1149-1167,
  1190-1239,1291-1325,1372-1384`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : le code utilise `dir.exists()` pour ETL/pipeline
  et `file.exists()` pour les RDS. Aucun contrôle de date, hash, paramètres,
  taille ou mtime n'est codé.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Dans la baseline `main.R`, quelle
  procédure ou convention garantit qu'un artefact ETL, pipeline ou RDS est
  cohérent avec les inputs et paramètres courants ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : le résultat de référence dépend
  potentiellement de l'état préalable du filesystem.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faut caractériser premier calcul,
  reprise valide et reprise d'un cache obsolète.
- **IMPACT — ARCHITECTURE TO-BE** : le statut et la validité des caches actifs
  ne peuvent pas être déduits du seul nom de fichier.
- **IMPACT — PLAN DE MIGRATION** : une migration peut produire des écarts en
  réutilisant ou invalidant différemment les artefacts.

### OQ-05 — Relances partielles et ordre opérationnel

- **ID** : OQ-05
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Les relances partielles de `main.R` sont-elles autorisées et
  lesquelles doivent être supportées ?
- **SOURCE** : `main.R:20-169` ; ancienne question `AS_IS.md:547-548`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : l'ordre du chemin complet est fixé par `main.R` :
  configuration, ETL conditionnel, pipeline conditionnel, introduction,
  expédition, contrôles, CNIV. Les relances partielles ne sont pas définies
  par un mécanisme dédié.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelles relances partielles du
  chemin `main.R` sont officiellement autorisées et quels artefacts peuvent
  être réutilisés dans chacune ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : aucun impact sur l'exécution complète,
  mais les scénarios de reprise restent incomplets.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests de reprise ne peuvent pas
  être fermés sans cette information.
- **IMPACT — ARCHITECTURE TO-BE** : faible impact sur le calcul nominal ;
  impact sur les interfaces de relance.
- **IMPACT — PLAN DE MIGRATION** : concerne surtout la continuité opérationnelle.

### OQ-06 — Chemins et environnement des inputs actifs

- **ID** : OQ-06
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels chemins locaux, réseau, VPN et Kayzer sont officiellement
  requis par le chemin `main.R` ?
- **SOURCE** : `config.R:66-117,163-364` ;
  `programs/Controles_imput_PC_yb.R:17-23` ; `README.md:20-39`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les chemins consommés par la baseline sont
  identifiés, notamment `input`, `ETL`, `pipeline`, `output_PC`, le partage
  `P:` et le chemin SIRENE Windows. Leur disponibilité réelle n'est pas dans
  le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quel environnement d'exécution
  est officiellement supporté pour le chemin `main.R`, et quels chemins sont
  obligatoires à chaque étape ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la provenance et la destination des
  données restent partiellement externes.
- **IMPACT — TESTS DE CARACTÉRISATION** : l'environnement des fixtures et des
  tests d'intégration n'est pas complètement défini.
- **IMPACT — ARCHITECTURE TO-BE** : les contrats I/O et dépendances système
  restent à confirmer.
- **IMPACT — PLAN DE MIGRATION** : risque de rupture de lecture ou d'export.

### OQ-07 — Publication et validation externe

- **ID** : OQ-07
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Quels aspects de publication ou de copie externe du chemin
  `main.R` sont obligatoires après production ?
- **SOURCE** : `README.md:31-39` ; `main.R:163-169` ; appels commentés dans
  `launch_introduction.R:78-86` et `launch_expedition.R:99-154`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : la baseline de calcul est fixée, mais le dépôt
  ne permet pas de trancher entre les copies réseau documentées et les copies
  actuellement commentées.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelles copies, publications et
  validations externes des outputs produits par `main.R` sont obligatoires ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : aucun changement de règle de calcul,
  mais le périmètre de livraison reste incomplet.
- **IMPACT — TESTS DE CARACTÉRISATION** : peut ajouter des assertions de
  présence ou de copie, sans modifier les valeurs calculées.
- **IMPACT — ARCHITECTURE TO-BE** : concerne les interfaces de livraison,
  hors cœur métier.
- **IMPACT — PLAN DE MIGRATION** : peut affecter l'acceptation opérationnelle.

### OQ-11 — Provenance et version des inputs

- **ID** : OQ-11
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelle procédure produit, valide et versionne les inputs
  consommés par `main.R` ?
- **SOURCE** : `config.R:133-364` ; `README.md:20-28` ;
  `main.R:57-138`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : les noms, périodes, répertoires et paramètres de
  lecture sont codés. La procédure de génération, validation, dépôt et
  remplacement des fichiers externes ne l'est pas.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure produit, valide
  et versionne chaque input attendu par le chemin `main.R` ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la définition d'un input valide reste
  incomplète.
- **IMPACT — TESTS DE CARACTÉRISATION** : les fixtures et contrôles de fraîcheur
  ne peuvent pas être fixés.
- **IMPACT — ARCHITECTURE TO-BE** : les contrats d'entrée restent incomplets.
- **IMPACT — PLAN DE MIGRATION** : risque de confondre une différence de
  producteur avec une différence de traitement.

### OQ-12 — Ventilation expédition incluant le régime 29

- **ID** : OQ-12
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quelle règle métier doit s'appliquer à la ventilation des
  prédictions expédition du régime 29 ?
- **SOURCE** : `programs/launch_expedition.R:24-55,76-84,125-151` ;
  `programs/NR.R:1107-1125` ; `BUSINESS_LOGIC_AS_IS.md:668-704`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les régimes 21 et 29 sont estimés séparément,
  puis additionnés dans `exped_imput`. La ventilation globale est appelée avec
  `expedition_21` et le détail renommé `vart_21`. Aucun appel direct de
  ventilation 29 n'est atteint depuis `main.R`.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Les prédictions du régime 29
  doivent-elles être ventilées directement, avec la structure 21, ou rester
  uniquement dans les exports agrégé et par régime ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la règle de production des ventilations
  expédition n'est pas fermée.
- **IMPACT — TESTS DE CARACTÉRISATION** : aucune valeur attendue fiable ne peut
  être fixée pour la ventilation du régime 29.
- **IMPACT — ARCHITECTURE TO-BE** : le contrat de ventilation par régime reste
  indéterminé.
- **IMPACT — PLAN DE MIGRATION** : impossible de distinguer conservation et
  correction de l'asymétrie actuelle.

### OQ-13 — Intention métier de `vart_21`

- **ID** : OQ-13
- **CRITICITÉ** : BLOCKER
- **QUESTION** : L'utilisation de `vart_21` pour ventiler le résultat
  expédition global incluant le régime 29 est-elle une règle validée ?
- **SOURCE** : `programs/launch_expedition.R:50-55` ; `programs/NR.R:1108-1124` ;
  `BUSINESS_LOGIC_AS_IS.md:720-723`.
- **ÉTAT** : NON RÉSOLVABLE STATIQUEMENT
- **INVESTIGATION STATIQUE** : le choix technique est établi, mais son intention
  métier et sa conformité ne sont exprimées dans aucun fichier.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « L'utilisation de `vart_21` pour
  calculer les ratios de ventilation du résultat expédition global incluant le
  régime 29 est-elle une règle métier validée ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : impossible de qualifier l'asymétrie
  comme comportement requis ou anomalie.
- **IMPACT — TESTS DE CARACTÉRISATION** : les ventilations globales ne peuvent
  pas recevoir d'oracle métier certain.
- **IMPACT — ARCHITECTURE TO-BE** : les données de ventilation à préserver ne
  sont pas définies.
- **IMPACT — PLAN DE MIGRATION** : le choix entre reproduction stricte et
  changement de comportement reste ouvert.

### OQ-14 — Outputs contractuels et usages aval

- **ID** : OQ-14
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels outputs de `main.R` sont contractuels pour les
  utilisateurs et les traitements aval ?
- **SOURCE** : `programs/Controles_imput_PC_yb.R:44-146` ;
  `programs/launch_cniv.R:36-81` ; ancienne question `AS_IS.md:658-659`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les producteurs et certains consommateurs
  internes sont identifiés. Le dépôt ne définit pas le statut officiel de
  chaque CSV, RDS et XLSX ni les consommateurs externes.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels fichiers produits par
  `main.R` sont obligatoires pour l'acceptation de la production, et lesquels
  sont uniquement intermédiaires ou de contrôle ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les sorties obligatoires ne sont pas
  toutes identifiées.
- **IMPACT — TESTS DE CARACTÉRISATION** : les assertions de non-régression ne
  peuvent pas hiérarchiser les fichiers.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces de sortie restent ouvertes.
- **IMPACT — PLAN DE MIGRATION** : risque de supprimer une sortie consommée
  hors dépôt.

### OQ-15 — Cas limites des ratios de ventilation

- **ID** : OQ-15
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quel comportement est attendu lorsqu'aucune structure
  historique ou aucun ratio valide n'est disponible ?
- **SOURCE** : `programs/NR.R:1029-1075` ; `BUSINESS_LOGIC_AS_IS.md:588-591`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : `ratio = endo / sum_endo` est calculé sans garde,
  et la jointure sur `period_last` n'a aucun fallback explicite. Le code
  établit l'absence de traitement dédié, mais pas le comportement métier voulu.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « En cas de ratio indéfini, de
  période précédente absente ou de clé historique manquante, faut-il produire
  une valeur manquante, exclure la ligne, redistribuer le total ou arrêter le
  traitement ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les règles des cas limites restent
  incomplètes.
- **IMPACT — TESTS DE CARACTÉRISATION** : les valeurs attendues des cas zéro,
  vide et première période ne sont pas fixées.
- **IMPACT — ARCHITECTURE TO-BE** : les garanties de sortie sont indéterminées.
- **IMPACT — PLAN DE MIGRATION** : un traitement explicite pourrait changer les
  totaux sans oracle permettant de distinguer correction et régression.

### OQ-16 — Contrat des artefacts actifs

- **ID** : OQ-16
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quels artefacts lus par `main.R` sont des contrats persistants
  et lesquels sont des caches recalculables ?
- **SOURCE** : `main.R:57-138` ; `programs/NR.R:953-974,1149-1167` ;
  ancienne question `AS_IS.md:658-659`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les artefacts ETL/pipeline sont lus directement
  par `main.R`; les RDS d'estimation, ventilation, historique, Gazelec et MSD
  pilotent des reprises. Aucun contrat de conservation ou de version n'est
  déclaré.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels artefacts ETL, pipeline et
  RDS doivent être conservés comme interfaces ou historiques, et lesquels
  peuvent être supprimés puis recalculés ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la persistance peut faire partie du
  comportement de référence.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faut savoir si les tests portent
  sur les artefacts intermédiaires ou seulement sur les outputs finaux.
- **IMPACT — ARCHITECTURE TO-BE** : les frontières entre cache et interface ne
  sont pas définies.
- **IMPACT — PLAN DE MIGRATION** : risque de perdre une capacité de reprise ou
  un historique requis.

### OQ-17 — Intégrité des dossiers ETL et pipeline

- **ID** : OQ-17
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelle procédure s'applique lorsqu'un dossier ETL ou pipeline
  existe mais est incomplet ou corrompu ?
- **SOURCE** : `main.R:20-26,88-94` ; `Refactoring/import et prep.R:1-43` ;
  `Refactoring/prep pipeline.R:1-89` ; ancienne question `AS_IS.md:647-648`.
- **ÉTAT** : RÉSOLU STATIQUEMENT pour le dépôt, ouvert opérationnellement
- **INVESTIGATION STATIQUE** : le code teste seulement l'existence du dossier,
  pas la présence ou la cohérence de chaque artefact attendu. Aucun nettoyage
  ou rebuild complet n'est codé.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure de nettoyage ou
  reconstruction complète est utilisée lorsqu'un dossier ETL ou pipeline est
  partiel ou corrompu ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les conditions de reprise restent
  incomplètes.
- **IMPACT — TESTS DE CARACTÉRISATION** : les scénarios de dossiers partiels
  n'ont pas d'oracle métier.
- **IMPACT — ARCHITECTURE TO-BE** : les exigences d'intégrité des étapes ne
  sont pas établies.
- **IMPACT — PLAN DE MIGRATION** : risque de produire des dossiers mixtes
  indétectables après changement de format.

### OQ-18 — Versions R et packages du chemin actif

- **ID** : OQ-18
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelles versions de R, Java et des packages sont validées
  pour reproduire le chemin `main.R` ?
- **SOURCE** : `programs/NR.R:1-9` ; `programs/CNIV.R:1-5` ;
  `programs/Controles_imput_PC_yb.R:1-5` ; absence de manifeste local.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : les packages actifs sont identifiables, mais
  aucune version R/package/Java n'est fixée. Les scripts historiques hors
  baseline ne sont plus pertinents pour cette question de compatibilité.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelles versions de R, Java et des
  packages sont validées pour le chemin officiel `main.R` ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : un comportement observé peut dépendre
  d'une version non documentée.
- **IMPACT — TESTS DE CARACTÉRISATION** : la reproductibilité des tests reste
  incertaine.
- **IMPACT — ARCHITECTURE TO-BE** : les contraintes de compatibilité runtime
  restent ouvertes.
- **IMPACT — PLAN DE MIGRATION** : un écart peut provenir du runtime plutôt que
  du refactoring.

### OQ-20 — Volumes et contraintes de charge

- **ID** : OQ-20
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Quels volumes, durées, mémoire et niveau de parallélisme sont
  attendus pour une production `main.R` ?
- **SOURCE** : `main.R:14-15` ; `programs/NR.R:340-395,479-603` ; ancienne
  question `AS_IS.md:687-689`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : le code fixe des paramètres de parallélisme et
  appelle `memory.limit`, mais aucun volume cible, SLA ou capacité machine
  n'est documenté.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels sont les volumes usuels et
  maximaux, la durée cible, la mémoire disponible et le parallélisme validé
  pour la production `main.R` ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : aucun impact direct sur les règles de
  calcul ; les contraintes non fonctionnelles manquent.
- **IMPACT — TESTS DE CARACTÉRISATION** : impossible de définir les jeux de
  charge et seuils de performance.
- **IMPACT — ARCHITECTURE TO-BE** : les besoins de calcul et stockage restent
  indéterminés.
- **IMPACT — PLAN DE MIGRATION** : une migration fonctionnellement correcte
  peut rester inexploitable à volume réel.

### OQ-21 — Validation aval des contrôles et sorties CNIV

- **ID** : OQ-21
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels contrôles et fichiers CNIV constituent la validation
  officielle de la production `main.R` ?
- **SOURCE** : `programs/Controles_imput_PC_yb.R:149-618` ;
  `programs/launch_cniv.R:36-81` ; ancienne question `AS_IS.md:658-659`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les contrôles et producteurs CNIV sont dans le
  chemin actif. Les consommateurs humains ou systèmes externes et leurs
  critères d'acceptation ne sont pas dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels contrôles et fichiers CNIV
  sont nécessaires pour déclarer la production `main.R` validée, et qui les
  consomme ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la définition d'une production réussie
  reste incomplète.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests ne savent pas quels
  contrôles et classeurs doivent être comparés.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces aval restent ouvertes.
- **IMPACT — PLAN DE MIGRATION** : un output secondaire en apparence peut être
  indispensable à l'acceptation métier.

## 4. Questions fermées par la décision de baseline

### OQ-04 — Scripts hors `main.R`

**Statut : FERMÉ POUR LA COMPATIBILITÉ.** `launch_production.R`,
`launch_request.R`, `imputations_NATR.R`, `imputations_transport48Kv2.R`,
`prgm_C3290.R`, `programs/old/*`, `Controles_imput_C.R` et
`CNIV_zero_mois.R` ne sont pas atteignables depuis le chemin actif de
`main.R`. Leur usage externe éventuel ne modifie pas le référentiel de
compatibilité.

### OQ-08 — Statut des scripts anciens

**Statut : FERMÉ POUR LA COMPATIBILITÉ.** Leur support éventuel est une
question de maintenance ou d'exploitation séparée, pas une inconnue bloquant
la migration de `main.R`.

### OQ-09 — Producteur PostgreSQL

**Statut : FERMÉ POUR LA COMPATIBILITÉ.** `launch_request.R` n'est pas dans le
chemin baseline. La provenance des fichiers réellement présents dans `input/`
reste couverte par `OQ-11`.

### OQ-10 — Identifiants PostgreSQL

**Statut : FERMÉ POUR LA COMPATIBILITÉ, SIGNALÉ HORS PÉRIMÈTRE.** La présence
de secrets en clair reste un sujet de sécurité à traiter séparément, sans
constituer un blocker fonctionnel de la migration `main.R`.

### OQ-19 — Branches historiques

**Statut : FERMÉ POUR LA COMPATIBILITÉ.** Les branches non atteignables ne
doivent pas recevoir de tests de non-régression baseline, sauf dépendance
active découverte ultérieurement.

## 5. `REMAINING_DECISIONS_BEFORE_TO_BE`

Cette section contient uniquement les décisions humaines encore nécessaires
avant de définir le To-be. Elle ne propose aucune architecture.

### Décision 1 — Validité des caches actifs

- **QUESTION** : Quelle règle détermine qu'un cache ETL, pipeline ou RDS est
  valide avant réutilisation ?
- **POURQUOI ELLE BLOQUE OU NON** : **BLOQUE** la caractérisation si un cache
  obsolète peut modifier les résultats de référence ; ne bloque pas la lecture
  du chemin nominal lorsque les artefacts sont déjà connus comme valides.
- **COMPORTEMENT ACTUEL ÉTABLI** : `main.R` utilise `dir.exists()` pour ETL et
  pipeline ; les fonctions NR utilisent `file.exists()` pour relire les RDS,
  sans validation de contenu ou de paramètres.
- **DÉCISION HUMAINE NÉCESSAIRE** : confirmer la procédure de validation,
  d'invalidation et de reconstruction des caches.

### Décision 2 — Contrat des artefacts persistants

- **QUESTION** : Quels artefacts ETL, pipeline et RDS sont des interfaces ou
  historiques à conserver, et lesquels sont recalculables ?
- **POURQUOI ELLE BLOQUE OU NON** : **BLOQUE** la migration si la suppression
  ou la transformation d'un artefact rompt une reprise ou un consommateur.
- **COMPORTEMENT ACTUEL ÉTABLI** : `main.R` lit les Arrow/Parquet préparés ;
  `NR.R` relit les RDS d'estimation, ventilation, historique, Gazelec et MSD.
- **DÉCISION HUMAINE NÉCESSAIRE** : classer chaque artefact actif comme
  contrat, historique, cache ou sortie livrable.

### Décision 3 — Ventilation du régime 29

- **QUESTION** : Comment les prédictions expédition du régime 29 doivent-elles
  être ventilées ?
- **POURQUOI ELLE BLOQUE OU NON** : **BLOQUE** la caractérisation des sorties
  expédition et le choix entre reproduction et changement de comportement.
- **COMPORTEMENT ACTUEL ÉTABLI** : les régimes 21 et 29 sont estimés puis
  additionnés ; la ventilation active est appelée avec `expedition_21` et
  `vart_21`.
- **DÉCISION HUMAINE NÉCESSAIRE** : confirmer ventilation directe 29, usage de
  la structure 21 ou absence de ventilation 29.

### Décision 4 — Cas limites des ratios

- **QUESTION** : Que faire lorsqu'un ratio est indéfini ou qu'une structure
  historique manque ?
- **POURQUOI ELLE BLOQUE OU NON** : **IMPORTANT**, car les cas limites doivent
  recevoir une valeur attendue dans les tests ; non blocker pour les données
  nominales qui disposent d'une structure valide.
- **COMPORTEMENT ACTUEL ÉTABLI** : `distribution()` calcule `endo / sum_endo`
  et joint sur `period_last`, sans fallback explicite.
- **DÉCISION HUMAINE NÉCESSAIRE** : confirmer sortie manquante, exclusion,
  redistribution ou arrêt du traitement.

### Décision 5 — Outputs contractuels

- **QUESTION** : Quels CSV, RDS, XLSX et contrôles produits par `main.R` sont
  obligatoires pour accepter une production ?
- **POURQUOI ELLE BLOQUE OU NON** : **IMPORTANT**, car la migration doit
  préserver les interfaces aval ; non blocker pour le calcul interne.
- **COMPORTEMENT ACTUEL ÉTABLI** : les contrôles PC relisent les CSV de
  `output_PC`; CNIV écrit des CSV/XLSX locaux et réseau.
- **DÉCISION HUMAINE NÉCESSAIRE** : établir la liste des outputs livrables et
  des validations faisant foi.

### Décision 6 — Inputs et environnement officiellement supportés

- **QUESTION** : Quelle provenance d'inputs et quel environnement réseau/local
  sont officiellement requis par `main.R` ?
- **POURQUOI ELLE BLOQUE OU NON** : **IMPORTANT** pour la reproductibilité et
  les tests d'intégration ; non blocker pour la lecture statique du code.
- **COMPORTEMENT ACTUEL ÉTABLI** : `config.R` fixe les noms, périodes et
  chemins d'inputs, historiques, CA3, SIRENE, Polyco et CNIV.
- **DÉCISION HUMAINE NÉCESSAIRE** : confirmer la procédure de production,
  validation et versionnement des inputs ainsi que l'environnement supporté.

### Décision 7 — Runtime validé

- **QUESTION** : Quelles versions de R, Java et packages sont validées pour
  exécuter `main.R` ?
- **POURQUOI ELLE BLOQUE OU NON** : **IMPORTANT** pour reproduire les résultats
  et isoler les écarts de migration ; non blocker pour le modèle conceptuel.
- **COMPORTEMENT ACTUEL ÉTABLI** : les packages actifs sont chargés par les
  scripts, mais aucune version n'est fixée dans le dépôt.
- **DÉCISION HUMAINE NÉCESSAIRE** : fournir l'environnement validé de la
  baseline.

### Décision 8 — Relances partielles

- **QUESTION** : Quelles relances partielles sont officiellement supportées ?
- **POURQUOI ELLE BLOQUE OU NON** : **NON BLOCKER** pour la baseline complète ;
  important pour l'exploitation et la reprise après incident.
- **COMPORTEMENT ACTUEL ÉTABLI** : l'ordre complet de `main.R` est séquentiel,
  mais aucune procédure de relance partielle n'est codée.
- **DÉCISION HUMAINE NÉCESSAIRE** : confirmer les étapes relançables et les
  artefacts réutilisables.

### Décision 9 — Contraintes de charge

- **QUESTION** : Quels volumes et seuils de performance la production doit-elle
  supporter ?
- **POURQUOI ELLE BLOQUE OU NON** : **NON BLOCKER** pour la caractérisation
  fonctionnelle ; secondaire pour la migration opérationnelle.
- **COMPORTEMENT ACTUEL ÉTABLI** : `main.R` appelle `memory.limit()` et les
  méthodes NR utilisent du parallélisme, sans volume cible documenté.
- **DÉCISION HUMAINE NÉCESSAIRE** : fournir volumes, durée cible, mémoire et
  parallélisme validés.

## Conclusion

Après la décision de baseline, les inconnues relatives aux scripts non
atteignables ne bloquent plus la migration. Les blockers restants concernent
uniquement les caches actifs, les artefacts lus par `main.R` et la règle métier
de ventilation expédition 21/29. Aucune proposition To-be n'est incluse.
