# Rapport As-is — `imputations`

## Périmètre et méthode

Ce rapport couvre uniquement les phases 1 à 5 de la mission : inventaire,
reconstruction forward, reconstruction backward, cartographie As-is et audit
adversarial. Il ne propose ni migration ni refactoring.

Les catégories utilisées sont les suivantes :

- **FAIT OBSERVÉ** : directement visible dans le code ou l'arborescence ;
- **INFÉRENCE** : interprétation déduite de plusieurs faits ;
- **INCONNU** : non déterminable statiquement ;
- **RECOMMANDATION** : volontairement exclue de ce checkpoint.

L'analyse est statique. Le pipeline n'a pas été exécuté. Les répertoires de
données externes et les artefacts générés à l'exécution ne sont pas présents
dans l'arborescence suivie du dépôt au moment de l'analyse.

## Phase 1 — Inventaire du repository

### Entry points et scripts atteignables depuis `main.R`

**FAIT OBSERVÉ —** `main.R` est l'entry point principal déclaré par le README
(`README.md:15-18`) et source successivement :

1. `config.R` et `programs/Production.R`, `programs/CNIV.R`
   (`main.R:4-12`) ;
2. conditionnellement `Refactoring/import et prep.R` si `ETL/` n'existe pas
   (`main.R:20-26`) ;
3. conditionnellement `Refactoring/prep pipeline.R` si `pipeline/` n'existe
   pas (`main.R:88-94`) ;
4. `programs/launch_introduction.R` (`main.R:144-146`) ;
5. `programs/launch_expedition.R` (`main.R:150-152`) ;
6. `programs/Controles_imput_PC_yb.R` (`main.R:163-165`) ;
7. `programs/launch_cniv.R` (`main.R:167-169`).

`programs/launch_production.R` et trois anciens scripts de production sont
présents mais commentés dans `main.R:154-160`.

### Inventaire par zone

| Zone | Fichiers | Statut observé |
|---|---|---|
| Racine | `main.R`, `config.R`, `README.md` | Entrée, configuration, documentation |
| Import historique | `programs/Input.R`, `programs/MSDtreatment.R`, `programs/common_functions.R` | Chargé par la configuration ou par les scripts actifs |
| Métier non-réponse | `programs/NR.R`, `launch_introduction.R`, `launch_expedition.R` | Chaîne active principale |
| Contrôles | `Controles_imput_PC_yb.R`, `fonctions_controles_yb.R` | Contrôles appelés par `main.R` |
| CNIV | `CNIV.R`, `launch_cniv.R` | Chargé et appelé par `main.R` |
| Production | `Production.R`, `launch_production.R` | Classe chargée ; lancement commenté |
| Requêtes | `launch_request.R` | Script autonome non sourcé par `main.R` |
| Anciens scripts | `programs/old/*`, `Controles_imput_C.R`, `imputations_NATR.R`, `imputations_transport48Kv2.R`, `prgm_C3290.R`, `CNIV_zero_mois.R` | Présents ; non démontrés comme actifs dans le chemin principal |
| Refactoring préparatoire | `Refactoring/import et prep.R`, `Refactoring/prep pipeline.R`, `Refactoring/Fonctions/*.R`, `Refactoring/tests.R` | Partiellement intégré à `main.R`, avec persistance intermédiaire |

Les fichiers R du dépôt sont les suivants :

```text
main.R
config.R
programs/Input.R
programs/MSDtreatment.R
programs/NR.R
programs/Production.R
programs/CNIV.R
programs/CNIV_zero_mois.R
programs/common_functions.R
programs/launch_introduction.R
programs/launch_expedition.R
programs/launch_production.R
programs/launch_cniv.R
programs/launch_request.R
programs/Controles_imput_PC_yb.R
programs/Controles_imput_C.R
programs/fonctions_controles_yb.R
programs/imputations_NATR.R
programs/imputations_transport48Kv2.R
programs/prgm_C3290.R
programs/old/Controles_imput_PC.R
programs/old/fonctions_controles.R
Refactoring/import et prep.R
Refactoring/prep pipeline.R
Refactoring/tests.R
Refactoring/Fonctions/ETL_delete_data.R
Refactoring/Fonctions/data_treatment.R
Refactoring/Fonctions/import_ER.R
Refactoring/Fonctions/import_ca3.R
Refactoring/Fonctions/import_detail.R
Refactoring/Fonctions/import_endogenous.R
Refactoring/Fonctions/import_msd.R
Refactoring/Fonctions/import_samples_transform.R
```

### Fonctions, classes et méthodes

**FAIT OBSERVÉ —** Le code définit quatre classes S4 principales :

- `Input` dans `programs/Input.R:50-79` ;
- `NR` dans `programs/NR.R:24` ;
- `Production` dans `programs/Production.R:7-11` ;
- `CNIV` dans `programs/CNIV.R:11-14`.

`programs/CNIV_zero_mois.R:11-14` redéfinit également une classe `CNIV` et
des méthodes portant les mêmes noms, mais ce fichier n'est pas sourcé par le
chemin principal observé.

Les méthodes S4 métier principales sont :

- `Input` : `import_delete`, `import_endogenous`, `import_detail`,
  `import_ER`, `import_historical_simulation`, `import_gazelec`,
  `import_pass_table`, `import_confederation_table`
  (`programs/Input.R:270-862`) ;
- `NR` : estimation, distribution, reprise historique, ajout Gazelec,
  suppression MSD (`programs/NR.R:133-1384`) ;
- `Production` : formats national, Eurostat SH2 et Eurostat CTCI
  (`programs/Production.R:13-91`) ;
- `CNIV` : estimation médiane, couverture et construction de fichiers
  (`programs/CNIV.R:16-367`).

Les fonctions ordinaires importantes sont notamment :

- import et préparation : `import_sample`, `get_sample_by_flow`,
  `import_ca3`, `data_treatment` (`programs/Input.R:155-258`, `548-588`) ;
- orchestration NR : `get_NR_list`, `get_flow_name`,
  `get_flow_name_register`, `export_imput_to_csv`, `export_ventil_to_csv`,
  `get_NR_list_from_result` (`programs/NR.R:838-873`, `1393-1465`) ;
- Refactoring : `ETL_delete_data`, `import_samples_transform`, `import_msd`,
  `import_endogenous`, `import_ER`, `import_detail`, `import_ca3`
  (`Refactoring/Fonctions/*.R`) ;
- contrôles : fonctions `ctrl_*`, `list_seuil_pred`, `revis_lastm`, `histo_m`
  (`programs/fonctions_controles_yb.R:8-266`) ;
- requêtes : `WriteCommand` et la boucle de requêtes PostgreSQL
  (`programs/launch_request.R:12-119`).

### Chargements et dépendances

**FAIT OBSERVÉ —** Les appels `source()` statiques sont recensés ci-dessous.

```text
main.R
├── config.R
│   ├── programs/Input.R
│   │   └── programs/MSDtreatment.R
│   └── Refactoring/tests.R
├── programs/Production.R
├── programs/CNIV.R
├── [si ETL/ absent] Refactoring/import et prep.R
│   ├── Refactoring/Fonctions/import_samples_transform.R
│   ├── Refactoring/Fonctions/ETL_delete_data.R
│   └── Refactoring/Fonctions/import_msd.R
├── [si pipeline/ absent] Refactoring/prep pipeline.R
│   ├── Refactoring/Fonctions/import_ca3.R
│   ├── Refactoring/Fonctions/import_endogenous.R
│   ├── Refactoring/Fonctions/import_ER.R
│   └── Refactoring/Fonctions/import_detail.R
│       └── Refactoring/Fonctions/data_treatment.R
├── programs/launch_introduction.R
│   └── programs/NR.R
├── programs/launch_expedition.R
│   └── programs/NR.R
├── programs/Controles_imput_PC_yb.R
│   └── programs/fonctions_controles_yb.R
└── programs/launch_cniv.R
```

Les chemins sont majoritairement relatifs au répertoire de travail courant.
Les fonctions sont toutefois évaluées dans l'environnement global créé par
les `source()` et les objets produits par les scripts sont réutilisés par les
étapes suivantes.

### Inputs externes et paramètres

`config.R` fixe notamment la date de référence `2026-06-01`, les dates de
publication/prédiction, le nombre de processus, les options historiques et
Gazelec (`config.R:12-50`). Il déclare :

- `input/` comme répertoire local des inputs (`config.R:66`) ;
- `ETL/`, `pipeline/` et `output_PC/` (`config.R:67-69`) ;
- un partage `P:/stat/01_etudes-methodes/@commun/EMEBI`
  (`config.R:70`) ;
- des inputs échantillon, historiques, imputation, ventilation, ER, CA3,
  Gazelec, tables Polyco et CNIV (`config.R:91-364`) ;
- une base CA3 relative `../dsece-imputation-nr/CA3 Parquet/`
  (`config.R:303-306`).

Le README confirme les dépendances réseau, VPN, boîte fonctionnelle et
fichiers parquet CA3 (`README.md:20-28`).

### Formats lus et écrits

**FAIT OBSERVÉ —** Les formats suivants apparaissent dans le code :

- CSV/CSV2 : inputs métier, exports d'imputation, ventilation et CNIV ;
- XLS/XLSX : tables Polyco, tables de référence et exports CNIV ;
- RDS : échantillon, suppressions, inputs historiques, caches de calcul,
  résultats intermédiaires et base historique ;
- Arrow Feather : `ETL/echantillon.arrow`, `ETL/MSD.arrow`,
  `pipeline/exogenous_intro.arrow`, `pipeline/endogenous_intro.arrow`,
  `pipeline/endogenous_exped.arrow`, `pipeline/etats_recap.arrow` ;
- Arrow Dataset/Parquet : `pipeline/detail_intro`, `pipeline/detail_exped`,
  base CA3 et base SIRENE (`main.R:57-138`, `programs/Input.R:113-153`,
  `programs/Controles_imput_PC_yb.R:184-194`).

## Phase 2 — Reconstruction forward

### Initialisation

1. `main.R` charge la configuration et les classes/fonctions de base.
2. `config.R` charge `Input.R`, déclare les chemins et construit les tables
   de description des fichiers.
3. `Input(...)` construit un objet S4 global `input_object`
   (`main.R:30-55`).
4. Si `ETL/` manque, les données d'échantillon, suppressions et MSD sont
   importées puis matérialisées par `Refactoring/import et prep.R:1-43`.
5. `main.R` lit les artefacts Arrow ETL (`main.R:57-84`).
6. Si `pipeline/` manque, CA3, données endogènes, ER et détails de ventilation
   sont préparés puis persistés (`Refactoring/prep pipeline.R:1-89`).
7. `main.R` lit les artefacts Arrow/Parquet pipeline (`main.R:96-138`).

### Introduction

`launch_introduction.R` :

1. construit `introduction <- NR(...)` à partir de `endogenous_intro` et
   `exogenous_intro` (`programs/launch_introduction.R:7-13`) ;
2. appelle `launch_all_estimations` sur `date_prediction`
   (`:18-25`) ;
3. appelle `launch_all_distributions` sur `detail_intro` (`:29-35`) ;
4. ajoute les mois historiques (`:40-46`) ;
5. ajoute les données Gazelec (`:51-65`) ;
6. retire les non-répondants présents dans MSD (`:70-76`, `:89-95`) ;
7. exporte les imputations mensuelles et la ventilation en CSV2
   (`:78-99`).

Les estimations et distributions globales peuvent être reprises depuis des
RDS existants (`programs/NR.R:953-975`, `1149-1170`). Sinon, elles sont
calculées date par date puis sauvegardées.

### Expédition

`launch_expedition.R` construit deux objets `NR` : régime 29 sans exogène et
régime 21 avec ER (`programs/launch_expedition.R:7-19`). Il :

1. estime les deux régimes (`:24-33`) ;
2. agrège leurs résultats dans `exped_imput` (`:34-46`) ;
3. ventile avec le détail expédition (`:50-55`) ;
4. ajoute les mois historiques (`:60-66`) ;
5. applique Gazelec aux résultats généraux et au régime 29 (`:71-84`) ;
6. retire les MSD puis exporte les résultats globaux, régime 21, régime 29 et
   la ventilation (`:89-151`).

### Contrôles

`Controles_imput_PC_yb.R` recherche les exports dans `output_PC/`, charge les
tables de nomenclature et les CSV d'imputation/ventilation
(`programs/Controles_imput_PC_yb.R:15-146`), puis appelle les contrôles de
`fonctions_controles_yb.R` (`:149-180`). Il ouvre ensuite une base SIRENE
parquet à chemin absolu Windows (`:22-23`, `:184-194`) et produit des listes
et contrôles complémentaires ; une persistance de l'historique est réalisée
à la ligne `618`.

### CNIV

`launch_cniv.R` relit `intro_ventil_rect.rds` et `exped_ventil_rect.rds`
(`programs/launch_cniv.R:2-3`), en déduit `NR_list`, importe les tables CNIV,
construit `cniv_data`, puis estime les produits vin/spiritueux
(`:6-34`). Il écrit un CSV médian, un XLSX de couverture, des fichiers par
confédération et copie le dossier vers le partage (`:36-81`).

### Branches et paramètres influents

- absence de `ETL/` : exécution de la préparation ETL ; présence : lecture
  directe des artefacts (`main.R:20-26`) ;
- absence de `pipeline/` : exécution de la préparation pipeline ; présence :
  lecture directe (`main.R:88-94`) ;
- `use_historical_basis`, `save_historical_input`, `use_gazelec_file` et
  `add_gazelec_data` modifient les imports et post-traitements
  (`config.R:40-50`, `programs/Input.R:350-462`, `programs/NR.R:1294-1325`) ;
- `file.exists()` dans les fonctions NR sélectionne le cache ou le recalcul
  (`programs/NR.R:956-974`, `1152-1168`, `1194-1239`, `1291-1325`,
  `1372-1384`) ;
- les exports réseau sont présents mais plusieurs appels sont commentés dans
  les scripts d'introduction/expédition (`launch_introduction.R:78-86`,
  `launch_expedition.R:93-104`, `110-123`, `130-143`, `149-154`).

## Phase 3 — Reconstruction backward

### Outputs observables et producteurs

| Output | Producteur observé | Données consommées |
|---|---|---|
| `estim_intro_*_ref*.csv` | `export_imput_to_csv` via `launch_introduction.R:78-86` | `intro_imput_rect` |
| `estim_exped_*_ref*.csv` | `export_imput_to_csv` via `launch_expedition.R:93-143` | résultats expédition rectifiés |
| `ventil_intro_ref*.csv` | `export_ventil_to_csv` via `launch_introduction.R:97-99` | `intro_ventil_rect` |
| `ventil_exped_ref*.csv` | `export_ventil_to_csv` via `launch_expedition.R:149-151` | `exped_ventil_rect` |
| RDS `*_imput.rds` | `launch_all_estimations` (`NR.R:953-974`) | estimations date par date |
| RDS `*_ventil.rds` | `launch_all_distributions` (`NR.R:1149-1167`) | distributions date par date |
| RDS `*_with_past_month.rds` | `add_historical_simulation` (`NR.R:1190-1239`) | historique + résultat courant |
| RDS `*_with_gazelec.rds` | `add_gazelec` (`NR.R:1274-1325`) | résultat + Gazelec |
| RDS `*_rect.rds` | `remove_msd` (`NR.R:1359-1382`) | résultat + MSD |
| `wine_spirit/estim_ngp_median_ref*.csv` | `launch_cniv.R:29-41` | `cniv_data`, `NR_list` |
| `EXPORTATIONS_DEB-DAU_CNIV.xlsx` et variantes | `compute_coverage`, `build_ending_file` (`launch_cniv.R:55-78`) | estimation CNIV, tables de référence |
| artefacts Arrow/Parquet | scripts `Refactoring/*` | inputs externes et historiques |

### Remontée vers les inputs

Pour les exports d'imputation, la chaîne inverse observée est :

```text
CSV output
<- export_imput_to_csv / export_ventil_to_csv
<- remove_msd
<- add_gazelec
<- add_historical_simulation
<- launch_all_estimations / launch_all_distributions
<- NR::estimNR / distribution
<- NR_list, endogeneous, exogenous ou détail
<- ETL/pipeline Arrow et Parquet
<- input/*.csv, *.xlsx, CA3, historique, partage réseau
```

Pour CNIV :

```text
CSV/XLSX CNIV
<- response_median_predict / compute_coverage / build_ending_file
<- cniv_data + NR_list + confederation_data
<- cniv_file, intro_ventil_rect, exped_ventil_rect
<- exports de ventilation + tables CNIV réseau/input
```

### Comparaison forward/backward

**FAIT OBSERVÉ —** Les deux passes convergent pour la chaîne principale
introduction/expédition : les résultats générés par les étapes NR sont bien
ceux relus par les contrôles et CNIV.

**FAIT OBSERVÉ —** Les chemins suivants ne convergent pas vers un output actif
de `main.R` :

- `launch_production.R` et la classe `Production` sont chargés, mais le
  lancement est commenté (`main.R:154-160`) ;
- `programs/launch_request.R` produit des CSV via PostgreSQL, mais n'est pas
  sourcé par `main.R` ;
- les scripts `old/`, `Controles_imput_C.R`, `imputations_NATR.R`,
  `imputations_transport48Kv2.R` et `prgm_C3290.R` n'ont pas de lien actif
  démontré depuis `main.R` ;
- `CNIV_zero_mois.R` définit une variante CNIV, mais n'est pas sourcé dans le
  chemin observé.

**INCONNU —** La présence éventuelle d'un ordonnanceur, d'un appel manuel ou
d'un autre script d'entrée hors dépôt ne peut pas être déterminée par cette
analyse statique.

## Phase 4 — Cartographie As-is

### 4.1 Code graph

```text
main.R
├── config.R
│   ├── Input.R ──> MSDtreatment.R
│   └── tests.R
├── Production.R ──(classe/méthodes chargées, lancement commenté)
├── CNIV.R
├── [condition] import et prep.R
│   └── ETL functions
├── [condition] prep pipeline.R
│   └── pipeline functions
├── launch_introduction.R ──> NR.R
├── launch_expedition.R ────> NR.R
├── Controles_imput_PC_yb.R ──> fonctions_controles_yb.R
└── launch_cniv.R ──> CNIV.R + Input.R + résultats ventilation
```

Relations fichier → fonction principales :

```text
Input.R       -> Input, import_*, data_treatment, import_sample
NR.R          -> NR, launch_*, distribution, add_*, remove_msd, exports
CNIV.R        -> CNIV, response_median_predict, compute_coverage,
                 build_ending_file
Production.R  -> Production, Get*Format
Refactoring/* -> fonctions d'import ETL et pipeline
fonctions_controles_yb.R -> ctrl_* et génération de contrôles
```

Relations fonction → fonction particulièrement importantes :

```text
main -> Input -> import_* / data_treatment
main -> import/prep Refactoring -> write_* Arrow/Parquet
launch_* -> launch_all_estimations -> launch_estimation -> estimNR
launch_* -> launch_all_distributions -> launch_distribution -> distribution
launch_* -> add_historical_simulation -> import_historical_simulation
launch_* -> add_gazelec -> import_gazelec
launch_* -> remove_msd -> anti_join(MSD)
launch_cniv -> response_median_predict -> compute_coverage
controls -> ctrl_* -> CSV/Parquet contrôlés
```

### 4.2 Data flow

```text
Inputs locaux/réseau/DB
    ├── échantillons CSV --------------------┐
    ├── imputation/ventilation CSV ----------┤
    ├── MSD CSV ------------------------------┤
    ├── ER CSV -------------------------------┤
    ├── CA3 Parquet --------------------------┤
    ├── Gazelec CSV --------------------------┤
    ├── Polyco XLS/XLSX ----------------------┤
    ├── CNIV CSV/XLS/XLSX --------------------┤
    └── historique RDS / PostgreSQL ----------┘
                    |
                    v
        ETL/ et pipeline/ (Arrow Feather, Parquet)
                    |
                    v
        objets sample, delete, MSD, exogenous,
        endogenous, ER, detail_intro/detail_exped
                    |
                    v
        NR estimation -> distribution -> historique
        -> Gazelec -> MSD -> exports CSV
                    |
                    ├── output_PC/*.csv
                    ├── output_PC/*.rds
                    └── CNIV CSV/XLSX
```

Persistance explicite observée :

- `ETL/echantillon.arrow`, `ETL/MSD.arrow` : `Refactoring/import et prep.R:8-43` ;
- `ETL/delete_data.arrow` et `historique/delete.rds` :
  `Refactoring/Fonctions/ETL_delete_data.R:28-37` ;
- `pipeline/exogenous_intro.arrow`, `endogenous_*.arrow`,
  `etats_recap.arrow`, `detail_*` : `Refactoring/prep pipeline.R:8-87` ;
- caches RDS d'import dans `input/` et historiques dans le partage :
  `programs/Input.R:247-252`, `280-307`, `444-462`, `532-537`, `630-635` ;
- caches de simulation dans `output_PC/` : `programs/NR.R:917-926`,
  `972-973`, `1166-1167`, `1238`, `1324-1325`, `1381-1382` ;
- base historique `Base_historique.rds` : `programs/NR.R:1411-1440`.

### 4.3 Process flow

Le processus réellement montré par le code est :

```text
Configuration des dates et chemins
    -> contrôle de présence des inputs
    -> ETL échantillon / suppressions / MSD
    -> préparation CA3 / endogène / ER / détail
    -> lecture des objets préparés
    -> identification des non-répondants par échantillon et période
    -> estimation des imputations
    -> ventilation sur les détails historiques
    -> incorporation des mois historiques
    -> ajout éventuel Gazelec
    -> exclusion MSD
    -> export des imputations et ventilations
    -> contrôles PC
    -> estimation et exports CNIV
```

La structure « choix de méthode » et « estimation » est interne à `estimNR`
et ses méthodes S4 (`programs/NR.R:133-835`) ; la séparation exacte des
régimes et des méthodes utilisées n'est pas reconstituée ici au-delà des
appels observés.

### 4.4 Execution-state graph

```text
main démarre
    |
    +-- ETL existe ? -- oui --> lecture ETL/*.arrow
    |                 \ non -> import -> écriture ETL/*
    |
    +-- pipeline existe ? -- oui --> lecture pipeline/*
    |                      \ non -> import -> écriture pipeline/*
    |
    +-- cache estimation existe ? -- oui --> readRDS
    |                           \ non -> calcul -> saveRDS
    |
    +-- cache ventilation existe ? -- oui --> readRDS
    |                            \ non -> calcul -> saveRDS
    |
    +-- cache historique/Gazelec/MSD existe ? -- oui --> readRDS
                                      \ non -> transformation -> saveRDS
    |
    +-- exports output_PC relus par contrôles et CNIV
```

**FAIT OBSERVÉ —** Les mêmes fichiers persistants servent tantôt de cache de
reprise (`*_imput.rds`, `*_ventil.rds`, `*_with_gazelec.rds`, `*_rect.rds`),
tantôt d'interface entre étapes (`*.arrow`, `detail_*`, exports CSV). Le code
ne fournit pas une déclaration formelle distinguant ces rôles.

## Phase 5 — Audit adversarial du As-is

### A1 — Double chemin d'import

- **OBSERVATION** : `Input.R` contient un chemin d'import S4 historique, tandis
  que `main.R` charge aussi les fonctions `Refactoring/` et leurs artefacts.
- **EVIDENCE** : `main.R:20-138`, `programs/Input.R:208-676`,
  `Refactoring/import et prep.R:1-43`, `Refactoring/prep pipeline.R:1-89`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : migration progressive dont les deux couches sont
  conservées pour compatibilité.
- **UNRESOLVED QUESTIONS** : quelles fonctions S4 d'import sont encore
  nécessaires au-delà de `Input(...)` et des appels CNIV ?

### A2 — Persistance avec rôles ambigus

- **OBSERVATION** : les branches `file.exists()` réutilisent des RDS sans
  vérifier leur date de référence, leurs paramètres ou leur version.
- **EVIDENCE** : `programs/NR.R:953-975`, `1149-1170`, `1190-1239`,
  `1291-1325`, `1372-1384`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : mécanisme de reprise opérationnel construit à
  partir de conventions de nommage.
- **UNRESOLVED QUESTIONS** : qui invalide les caches après changement de
  configuration ou d'input ?

### A3 — Producteurs non atteignables depuis le chemin principal

- **OBSERVATION** : plusieurs producteurs d'exports existent mais sont
  commentés ou non sourcés.
- **EVIDENCE** : `main.R:154-160`, `programs/launch_production.R:1-38`,
  `programs/launch_request.R:72-119`, fichiers `programs/old/*`.
- **CONFIDENCE** : élevée pour l'absence d'appel statique dans `main.R`.
- **POSSIBLE EXPLANATION** : scripts relancés manuellement ou utilisés par un
  ancien processus documentaire.
- **UNRESOLVED QUESTIONS** : quels scripts sont réellement utilisés en
  production hors entry point principal ?

### A4 — Sources dynamiques et dépendance à l'environnement global

- **OBSERVATION** : les `source()` créent des fonctions et objets utilisés par
  des scripts ultérieurs sans passage explicite en argument ; plusieurs
  fonctions utilisent directement des variables globales comme `base_historique`
  ou `input_object`.
- **EVIDENCE** : `main.R:4-12`, `programs/Input.R:49`,
  `programs/Input.R:660`, `programs/NR.R:714` et `programs/launch_cniv.R:9-18`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : scripts de production conçus pour être exécutés
  dans une session interactive séquentielle.
- **UNRESOLVED QUESTIONS** : l'ordre de chargement est-il garanti par un
  ordonnanceur externe ?

### A5 — Chemins absolus et dépendances d'environnement

- **OBSERVATION** : plusieurs chemins Windows ou lecteurs réseau sont codés en
  dur, dont un chemin SIRENE qui ne correspond pas au partage principal.
- **EVIDENCE** : `config.R:70-117`, `config.R:163-199`, `config.R:315-364`,
  `programs/Controles_imput_PC_yb.R:22-23`, `README.md:20-28`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : exécution sur postes et lecteurs réseau
  standardisés de l'équipe.
- **UNRESOLVED QUESTIONS** : quels chemins sont disponibles selon les régimes
  de production (local, VPN, partage, Kayzer) ?

### A6 — Incohérences commentaires/code

- **OBSERVATION** : certains commentaires décrivent des exports réseau ou des
  comportements historiques alors que les appels correspondants sont
  commentés ; `README.md` décrit une organisation qui n'est pas entièrement
  visible dans l'arborescence actuelle.
- **EVIDENCE** : `programs/launch_introduction.R:78-86`,
  `programs/launch_expedition.R:99-104`, `README.md:31-39`.
- **CONFIDENCE** : élevée pour les appels commentés ; moyenne pour l'écart
  documentaire, les données externes n'étant pas dans le dépôt.
- **POSSIBLE EXPLANATION** : documentation et code mis à jour à des moments
  différents.
- **UNRESOLVED QUESTIONS** : quelle version du processus opérationnel fait foi ?

### A7 — Fichier chargé mais non utilisé ou usage non démontré

- **OBSERVATION** : `Production.R` est chargé par `main.R`, mais son objet n'est
  construit que dans un lanceur commenté ; `CNIV_zero_mois.R` et plusieurs
  scripts anciens définissent des fonctionnalités parallèles non atteignables
  statiquement.
- **EVIDENCE** : `main.R:4-12`, `main.R:154-160`, `programs/Production.R:7`,
  `programs/CNIV_zero_mois.R:11-21`, `programs/old/*`.
- **CONFIDENCE** : élevée pour le chemin `main.R`, inconnue pour des lancements
  externes.
- **POSSIBLE EXPLANATION** : reliquats historiques ou outils de reprise manuelle.
- **UNRESOLVED QUESTIONS** : faut-il les considérer comme supportés, archivés
  ou simplement non utilisés ?

### A8 — Fichiers consommés sans producteur local

- **OBSERVATION** : le chemin principal attend `input/`, historiques, CA3,
  fichiers réseau, tables SIRENE et CNIV qui ne sont pas générés par le dépôt.
- **EVIDENCE** : `config.R:66-364`, `main.R:57-138`,
  `programs/Controles_imput_PC_yb.R:184-194`.
- **CONFIDENCE** : élevée pour l'absence de ces fichiers dans l'arborescence
  versionnée analysée.
- **POSSIBLE EXPLANATION** : inputs opérationnels volontairement externalisés.
- **UNRESOLVED QUESTIONS** : quelles versions et règles de dépôt produisent
  ces inputs ?

### A9 — Producteur externe non intégré

- **OBSERVATION** : `launch_request.R` interroge PostgreSQL et écrit les CSV
  d'input, mais n'est pas appelé par `main.R`.
- **EVIDENCE** : `programs/launch_request.R:72-119` et absence de `source()`
  depuis `main.R`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : étape manuelle de collecte exécutée avant la
  production.
- **UNRESOLVED QUESTIONS** : le script est-il encore le producteur officiel
  des inputs ?

### A10 — Secret opérationnel dans le code

- **OBSERVATION** : `launch_request.R` contient des identifiants de connexion
  PostgreSQL en clair.
- **EVIDENCE** : `programs/launch_request.R:4-5`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : script interne ancien destiné à un poste contrôlé.
- **UNRESOLVED QUESTIONS** : ces identifiants sont-ils actifs, révoqués ou
  uniquement historiques ?

### A11 — Régimes et résultats partiellement asymétriques

- **OBSERVATION** : l'estimation expédition est calculée séparément pour les
  régimes 21 et 29, mais la ventilation utilise l'objet régime 21 et le détail
  renommé `vart_21`; le résultat global et les résultats par régime suivent des
  chemins différents.
- **EVIDENCE** : `programs/launch_expedition.R:7-19`, `24-55`, `71-84`,
  `89-151`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : règles métier spécifiques au régime de ventilation
  ou compromis historique.
- **UNRESOLVED QUESTIONS** : la ventilation du régime 29 est-elle volontairement
  exclue ou traitée indirectement ?

### A12 — Écarts potentiels entre préparation et relance

- **OBSERVATION** : `dir.exists()` pilote la réutilisation globale de `ETL/` et
  `pipeline/`; un dossier partiellement rempli est traité comme complet.
- **EVIDENCE** : `main.R:20-26`, `88-94`, écritures dans
  `Refactoring/import et prep.R:1-43` et `Refactoring/prep pipeline.R:1-89`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : les dossiers sont supposés être atomiquement
  créés par une exécution précédente.
- **UNRESOLVED QUESTIONS** : existe-t-il un contrôle d'intégrité externe ou une
  procédure de nettoyage/reconstruction complète ?

### A13 — Dépendance à des effets de bord d'I/O dans les fonctions métier

- **OBSERVATION** : les fonctions d'estimation, de reprise, d'ajout Gazelec et
  de suppression MSD calculent et écrivent des RDS dans le même appel.
- **EVIDENCE** : `programs/NR.R:890-927`, `946-975`, `1186-1240`,
  `1265-1327`, `1350-1384`.
- **CONFIDENCE** : élevée.
- **POSSIBLE EXPLANATION** : optimisation de durée et reprise après interruption.
- **UNRESOLVED QUESTIONS** : quels artefacts sont contractuels pour les
  utilisateurs et lesquels ne sont que des caches ?

### A14 — Défauts ou comportements statiques non résolus

- **OBSERVATION** : des éléments paraissent fragiles sans que leur comportement
  réel puisse être établi sans exécution et données : filtrage dynamique CNIV,
  redéfinitions de classes/fonctions, chemins relatifs de scripts `old`, et
  disponibilité de `memory.limit` selon la plateforme.
- **EVIDENCE** : `programs/CNIV.R:25-31`, `programs/CNIV_zero_mois.R:11-21`,
  `programs/old/Controles_imput_PC.R:67`, `main.R:14-15`.
- **CONFIDENCE** : moyenne, car l'impact dépend de l'environnement et des
  branches réellement utilisées.
- **POSSIBLE EXPLANATION** : code ancien non actif ou dépendant d'une version
  précise de R/packages.
- **UNRESOLVED QUESTIONS** : ces branches sont-elles encore exécutées et avec
  quelles versions de R et des packages ?

## Conclusion du checkpoint 1

**FAIT OBSERVÉ —** Le chemin principal visible est une production mensuelle
centrée sur `main.R`, avec une préparation ETL/pipeline conditionnelle, deux
flux d'imputation (introduction et expédition), des contrôles PC et un
traitement CNIV.

**FAIT OBSERVÉ —** Le dépôt contient simultanément une architecture S4
historique, une couche de préparation fonctionnelle dans `Refactoring/`, des
scripts de production non activés et des scripts anciens.

**INCONNU —** L'exécution réelle, les volumes, les versions d'artefacts, les
ordonnancements externes et l'usage opérationnel des scripts non atteignables
ne sont pas démontrables statiquement.

Ce rapport s'arrête aux phases 1 à 5. Aucun To-be ni changement de code n'est
inclus.

## Mise à jour de périmètre — décision de baseline `main.R`

**DÉCISION HUMAINE ACTÉE —** `main.R` est la baseline officielle à migrer. Le
comportement de référence pour les tests de non-régression est le chemin actif
statiquement atteignable depuis `main.R`.

Le périmètre de compatibilité comprend donc `config.R`, les modules chargés par
`main.R`, les préparations ETL/pipeline conditionnelles, les chaînes
introduction et expédition, les contrôles PC et CNIV. Les fonctions et fichiers
ne sont inclus que lorsqu'une dépendance active depuis ce chemin est observée.

Les scripts explicitement commentés ou non sourcés depuis `main.R` — notamment
`launch_production.R`, `launch_request.R`, les variantes historiques et les
scripts `old/` — sont hors périmètre de compatibilité, sauf découverte
ultérieure d'une dépendance active. Cette décision ferme leur statut comme
question de migration ; leur éventuel usage opérationnel, leur maintenance ou
la présence de secrets restent des sujets séparés.

Cette décision modifie les conclusions de l'audit de la manière suivante :

- A3, A7 et A14 ne sont plus des blockers de compatibilité : ils décrivent des
  branches non atteignables depuis la baseline, sauf dépendance active à
  découvrir ;
- A9 et A10 sont hors périmètre fonctionnel de la migration :
  `launch_request.R` et ses identifiants restent un sujet opérationnel ou de
  sécurité, mais ne définissent pas le comportement de référence de `main.R` ;
- les questions conservées pour la migration portent sur le chemin actif,
  notamment caches, artefacts ETL/pipeline/RDS, inputs actifs, outputs aval et
  asymétrie de ventilation expédition 21/29 ;
- l'absence d'ordonnanceur externe dans le dépôt ne remet plus en cause le
  choix de l'entry point, puisque celui-ci est désormais confirmé par décision
  humaine.

La cartographie As-is et ses faits observés restent inchangés pour le chemin
actif. Aucun comportement métier des méthodes NR ou de la ventilation n'est
réinterprété par cette décision.
