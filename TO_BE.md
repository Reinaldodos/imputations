# Architecture To-be fonctionnelle R

## Objectif

Décrire une cible lisible par un utilisateur R compétent, sans S4, R6 ni autre
couche OOP. Cette architecture est une cible de structure, pas un plan de
migration. Elle doit produire le même comportement observable que `main.R`.

## Vue globale

```text
main.R
  -> read_config()
  -> prepare_or_read_etl()
  -> build_input_data()
  -> prepare_or_read_pipeline()
  -> run_introduction()
  -> run_expedition()
  -> run_controls()
  -> run_cniv()
```

Chaque étape retourne une liste nommée. Les effets de bord sont effectués par
des fonctions I/O appelées explicitement par l'orchestration.

## Modules

### `config/`

Responsabilités : paramètres de dates, options, descriptions des fichiers,
chemins et paramètres de calcul. Les valeurs actuelles de `config.R` restent la
référence de première cible.

### `io/`

Responsabilités :

- lecture/écriture CSV2, XLSX, RDS, Arrow et Parquet ;
- copies locales/réseau ;
- noms et chemins d'artefacts ;
- `cache_exists()`, `read_cache()`, `write_cache()` ;
- aucune décision métier.

Les conventions actuelles de fichiers sont conservées dans les adaptateurs.

### `etl/`

Fonctions ordinaires pour échantillon, suppressions, MSD, CA3, endogènes, ER et
détails de ventilation. Chaque fonction accepte ses inputs et retourne une
tibble/data.frame ou une liste nommée.

### `imputation/`

Responsabilités :

- `identify_nonrespondents()` ;
- `select_method()` ;
- `take_exogenous()` ;
- `take_er()` ;
- `take_mean()` ;
- `take_last_year()` ;
- `run_sarima()` ;
- `run_regression()` ;
- `apply_estimation_fallbacks()` ;
- `normalize_predictions()`.

La décision est retournée explicitement par siren, avec `method_ref`. Le calcul
retourne `method`. Les deux champs restent distincts.

### `distribution/`

Responsabilités :

- sélectionner les colonnes de structure comme le fait `distribution()` ;
- agréger l'endogène ;
- calculer `sum_endo` et `ratio` ;
- construire `period_last` comme période précédente disponible ;
- joindre l'estimation et appliquer `prediction * ratio` ;
- conserver explicitement le chemin expédition avec `vart_21` ;
- ne pas introduire de fallback sur ratios manquants en première cible.

### `postprocess/`

Responsabilités : ajout historique, Gazelec, exclusion MSD, exports
d'imputation, exports de ventilation et persistance historique.

### `controls/` et `cniv/`

Responsabilités séparées pour les contrôles PC, l'estimation CNIV, les
couvertures et les exports XLSX/CSV associés.

## Interfaces fonctionnelles

```r
select_method(data, flow, regime, prediction_period,
              ref_period, endo_name, exogenous = NULL, er = NULL,
              nb_learning_year = 5)

estimate_imputation(data, method, prediction_period,
                    learning_first, options)

apply_estimation_fallbacks(prediction, data, fallback_options)

normalize_predictions(prediction, na_imput = TRUE,
                       negative_imput = TRUE)

distribute_predictions(estimation, detail_data, endo_name,
                       periods, distribution_options)

run_introduction(inputs, options)
run_expedition(inputs, options)
run_controls(outputs, inputs, options)
run_cniv(outputs, inputs, options)
run_main_pipeline(config)
```

Les fonctions retournent des tibbles/data.frames ou listes nommées. Les
wrappers I/O prennent en charge les formats et chemins existants sans changer
les noms, colonnes ou conventions de première cible.

## Data flow cible

```text
config
  -> input specifications
  -> ETL data
  -> normalized pipeline data
  -> introduction result
  -> expedition regime 21 result
  -> expedition regime 29 result
  -> consolidated expedition result
  -> historical/Gazelec/MSD post-processing
  -> CSV/RDS/XLSX outputs
  -> controls and CNIV
```

Les données de régime 21 et 29 restent séparées jusqu'au point de consolidation
actuel. La ventilation utilise la structure actuellement observée, y compris
`vart_21`, jusqu'à décision contraire de Diffusion.

## Séparation des responsabilités

| Responsabilité | Module cible | Effet autorisé |
|---|---|---|
| décision de méthode | `imputation/decision.R` | aucune écriture |
| calcul d'une méthode | `imputation/methods.R` | calcul, workers isolés |
| fallbacks | `imputation/fallbacks.R` | remplacement identique |
| normalisation | `imputation/normalize.R` | NA/négatifs identiques |
| ventilation | `distribution/` | ratios et jointures identiques |
| cache | `io/cache.R` | mêmes branches et artefacts |
| inputs/outputs | `io/` | mêmes formats et chemins |
| orchestration | `main.R`, `run_*.R` | même ordre |
| contrôles/CNIV | `controls/`, `cniv/` | mêmes sorties |

## Garanties de première cible

- aucune correction métier ;
- aucune nouvelle règle sur les ratios ;
- aucune modification de la priorité des méthodes ;
- aucune suppression de l'asymétrie de ventilation expédition ;
- aucun changement implicite de cache ;
- aucun changement de format ou nom d'output ;
- toute question ouverte reste référencée dans `BUSINESS_QUESTIONS.md`.
