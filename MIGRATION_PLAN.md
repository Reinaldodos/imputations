# Plan de migration incrémental — baseline `main.R`

## Contrat et stratégie

`FUNCTIONAL_EQUIVALENCE.md` est le contrat : tous les comportements `Axx` sont
obligatoires, les éléments `C` sont reproduits à l'identique et seuls les
mécanismes `B` peuvent être remplacés après comparaison. Les éléments `D` sont
hors périmètre.

Chaque tranche suit : `legacy S4 -> extraction pure -> tests -> bascule du
consommateur -> extraction suivante`. Une divergence Axx inexpliquée arrête la
tranche. Le legacy reste exécutable jusqu'à l'acceptation finale.

## T00 — Golden Master end-to-end

- **SCOPE** : fixture, configuration, runtime, filesystem, captures et comparateur.
- **LEGACY COMPONENT** : chemin actif complet `main.R`.
- **TARGET RESPONSIBILITY** : harness de référence, sans changement métier.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A01–A03, A18–A27 et tous les outputs observables.
- **TESTS REQUIRED BEFORE** : smoke test legacy, complétude inputs/artefacts et validation Diffusion.
- **IMPLEMENTATION STRATEGY** : Diffusion fournit inputs autorisés, config, état cache, runtime et chemins de fixture. Anonymiser seulement en conservant types, clés, périodes, NA, zéros, valeurs négatives, régimes, fallbacks et ventilation ; ne pas fabriquer de données représentatives.
- **COMPARISON LEGACY / NEW** : figer logs, ordre, non-répondants, `method_ref`, `method`, prédictions avant/après fallback, résultats 21/29/consolidés, ratios, historique, Gazelec, MSD, CSV2, RDS, Arrow/Parquet, CSV/XLSX, métadonnées, hashes et état filesystem. Oracle indépendant des tests unitaires.
- **ROLLBACK POINT** : aucun code modifié ; invalider uniquement la capture.
- **EXIT CRITERIA** : deux exécutions legacy identiques avec état initial identique et outputs complets.
- **RISK** : fixture incomplète ou non représentative.
- **READABILITY** : oracle concret du processus global.

Les données de production et les versions runtime absentes du dépôt doivent être
fournies avant T01.

## T01 — Identification des non-répondants

- **SCOPE** : `get_NR_list()` ; **LEGACY COMPONENT** : `NR.R:838-856` ; **TARGET RESPONSIBILITY** : `identify_nonrespondents(sample, endogenous, date)`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A04.
- **TESTS REQUIRED BEFORE** : U01 et fixture Golden Master.
- **IMPLEMENTATION STRATEGY** : extraire millésime, anti-jointure, endogène positive et période sans brancher immédiatement.
- **COMPARISON LEGACY / NEW** : sirens, périodes, ordre, types et doublons.
- **ROLLBACK POINT** : consommateur legacy inchangé. **EXIT CRITERIA** : unit et Golden Master identiques.
- **RISK** : dates, tri ou doublons. **READABILITY** : forte, règle pure isolée.

## T02 — Sélection de méthode

- **SCOPE** : `nobs`, `notna_exog`, seuil et `method_ref` ; **LEGACY COMPONENT** : `NR.R:662-770` ; **TARGET RESPONSIBILITY** : `select_method()`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A05–A08, A17.
- **TESTS REQUIRED BEFORE** : `nobs=0`, seuil-1, seuil, exogène, ER, introduction, expédition 21 et 29.
- **IMPLEMENTATION STRATEGY** : conserver l'ordre des trois branches, priorité ER et cas spécial 29 ; ne pas généraliser.
- **COMPARISON LEGACY / NEW** : table de décision et groupes de sirens.
- **ROLLBACK POINT** : aucun consommateur basculé. **EXIT CRITERIA** : mêmes décisions fixtures/Golden Master.
- **RISK** : inversion de priorité. **READABILITY** : très forte, table explicite.

## T03 — Méthodes simples

- **SCOPE** : exogène, ER, moyenne et M-12 ; **LEGACY COMPONENT** : `NR.R:133-305` ; **TARGET RESPONSIBILITY** : `take_exogenous()`, `take_er()`, `take_mean()`, `take_last_year()`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A09–A13.
- **TESTS REQUIRED BEFORE** : U09–U16, jointures absentes, NA, dates non contiguës et fallback moyenne.
- **IMPLEMENTATION STRATEGY** : une méthode à la fois, mêmes colonnes, jointures, `lag`, M-12 et labels.
- **COMPARISON LEGACY / NEW** : tibbles ligne à ligne.
- **ROLLBACK POINT** : adaptateur S4. **EXIT CRITERIA** : équivalence isolée et via adaptateur.
- **RISK** : modifier NA ou confondre période disponible et M-12. **READABILITY** : forte.

## T04 — Fallbacks et normalisation

- **SCOPE** : M-12 → moyenne, puis NA/négatifs vers zéro ; **LEGACY COMPONENT** : `NR.R:289-301,399-415,607-620,823-831` ; **TARGET RESPONSIBILITY** : `apply_estimation_fallbacks()` et `normalize_predictions()`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A13–A17.
- **TESTS REQUIRED BEFORE** : `alternative`, `na_imput`, `negative_imput` et erreurs modèles.
- **IMPLEMENTATION STRATEGY** : conserver sorties intermédiaires, `method`, `method_ref`, puis normalisation.
- **COMPARISON LEGACY / NEW** : avant fallback, après fallback, après zéro.
- **ROLLBACK POINT** : `estimNR()` legacy. **EXIT CRITERIA** : chaîne et labels identiques.
- **RISK** : normaliser trop tôt. **READABILITY** : très forte.

## T05 — SARIMA

- **SCOPE** : calcul par siren et parallélisme ; **LEGACY COMPONENT** : `NR.R:319-417` ; **TARGET RESPONSIBILITY** : `run_sarima()` et wrapper cluster.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A05, A06, A07, A14.
- **TESTS REQUIRED BEFORE** : `try-error`, forecast absent, NA, <=0 et série longue.
- **IMPLEMENTATION STRATEGY** : calcul séquentiel puis parallélisme ; conserver RG3, fenêtre et fallbacks.
- **COMPARISON LEGACY / NEW** : prédictions brutes, périodes, méthodes et NA.
- **ROLLBACK POINT** : worker legacy. **EXIT CRITERIA** : mêmes résultats et erreurs.
- **RISK** : différence numérique ou worker. **READABILITY** : gain si calcul/cluster séparés.

## T06 — Régression

- **SCOPE** : série, indicatrices, `lm`, `step`, prédiction et fallback ; **LEGACY COMPONENT** : `NR.R:425-624` ; **TARGET RESPONSIBILITY** : `run_regression()`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A05, A08, A15.
- **TESTS REQUIRED BEFORE** : erreurs `lm`/`step`, saisonnalité, NA et <=0.
- **IMPLEMENTATION STRATEGY** : conserver formule, fenêtre, indicatrices, `create_ts()` et backward step.
- **COMPARISON LEGACY / NEW** : données de modèle, prédictions et fallbacks.
- **ROLLBACK POINT** : chemin S4. **EXIT CRITERIA** : aucun écart fixtures/Golden Master.
- **RISK** : formule ou fenêtre modifiée. **READABILITY** : forte.

## T07 — Bascule estimation et suppression de `do.call(get(...))`

- **SCOPE** : décision, calcul, fallback et normalisation ; **LEGACY COMPONENT** : `estimNR()`, `NR.R:632-835` ; **TARGET RESPONSIBILITY** : `estimate_imputation()` avec appels explicites.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A04–A17.
- **TESTS REQUIRED BEFORE** : tous T01–T06 et Golden Master des imputations.
- **IMPLEMENTATION STRATEGY** : garder `NR` comme adaptateur d'entrée, puis remplacer `do.call(get(...))` par dispatch explicite.
- **COMPARISON LEGACY / NEW** : siren, période, `method_ref`, `method`, prediction et NA/zéro.
- **ROLLBACK POINT** : appel `estimNR()` S4. **EXIT CRITERIA** : introduction, 21 et 29 identiques.
- **RISK** : argument implicite oublié. **READABILITY** : forte.

## T08 — Ventilation

- **SCOPE** : groupes, agrégation, ratios, `period_last`, jointures et produit ; **LEGACY COMPONENT** : `NR.R:984-1128` ; **TARGET RESPONSIBILITY** : `distribute_predictions()`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A20–A22.
- **TESTS REQUIRED BEFORE** : ratio nul, clé absente, première période, dates non contiguës.
- **IMPLEMENTATION STRATEGY** : conserver groupes, tri, jointure, NA et `vart_21`, sans nouveau fallback.
- **COMPARISON LEGACY / NEW** : ratios, structure, `period_last`, lignes et `dist_prediction`.
- **ROLLBACK POINT** : `distribution()` S4. **EXIT CRITERIA** : introduction/expédition identiques.
- **RISK** : supposer M-12 ou corriger un ratio. **READABILITY** : très forte.

## T09 — Historique, Gazelec et MSD

- **SCOPE** : post-traitements et caches ; **LEGACY COMPONENT** : `NR.R:1177-1384`, launchers ; **TARGET RESPONSIBILITY** : trois fonctions ordinaires et wrappers I/O.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A23–A25.
- **TESTS REQUIRED BEFORE** : U26–U28 et intégration des deux flux.
- **IMPLEMENTATION STRATEGY** : historique → Gazelec → MSD, mêmes options, clés, noms et ordre.
- **COMPARISON LEGACY / NEW** : chaque intermédiaire et cache.
- **ROLLBACK POINT** : post-traitement S4 concerné. **EXIT CRITERIA** : objets et artefacts identiques.
- **RISK** : population ou ordre modifiés. **READABILITY** : forte.

## T10 — Cache et persistance

- **SCOPE** : RDS, ETL et pipeline ; **LEGACY COMPONENT** : `main.R:20-26,88-94`, `Input.R`, `NR.R:953-1382` ; **TARGET RESPONSIBILITY** : wrappers I/O sans registry/factory.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A02, A03, A26.
- **TESTS REQUIRED BEFORE** : Golden Master, présent/absent, partiel, relecture.
- **IMPLEMENTATION STRATEGY** : sortir les effets de bord sans nouvelle règle de cache ; conserver noms, formats et conditions.
- **COMPARISON LEGACY / NEW** : état filesystem, branche, contenu et artefacts.
- **ROLLBACK POINT** : wrapper legacy. **EXIT CRITERIA** : même comportement présent/absent.
- **RISK** : statut ou fraîcheur changés. **READABILITY** : forte.

## T11 — Launchers introduction/expédition

- **SCOPE** : orchestration des deux flux ; **LEGACY COMPONENT** : launchers actifs ; **TARGET RESPONSIBILITY** : `run_introduction(inputs, options)` et `run_expedition(inputs, options)`.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A01, A06–A08, A18–A25, A27.
- **TESTS REQUIRED BEFORE** : toutes tranches précédentes, Golden Master, persistance et outputs.
- **IMPLEMENTATION STRATEGY** : basculer un appel à la fois, conserver ordre, consolidation 21/29, historique, Gazelec, MSD et exports.
- **COMPARISON LEGACY / NEW** : objets intermédiaires et outputs complets.
- **ROLLBACK POINT** : retour indépendant par launcher. **EXIT CRITERIA** : end-to-end identique.
- **RISK** : blast radius et ordre des effets. **READABILITY** : forte si launchers courts.

## T12 — Contrôles et CNIV

- **SCOPE** : contrôles PC, CNIV et writers ; **LEGACY COMPONENT** : `Controles_imput_PC_yb.R`, `CNIV.R`, `launch_cniv.R` ; **TARGET RESPONSIBILITY** : fonctions ordinaires et writers séparés.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A27 et outputs A23–A26.
- **TESTS REQUIRED BEFORE** : fixtures nomenclature, contrôles, CSV/XLSX et outputs validés.
- **IMPLEMENTATION STRATEGY** : contrôles puis CNIV, mêmes seuils, feuilles, fichiers, formats et copies.
- **COMPARISON LEGACY / NEW** : tables, contrôles, CSV/XLSX et historiques.
- **ROLLBACK POINT** : retour indépendant contrôles/CNIV. **EXIT CRITERIA** : mêmes fichiers et validation.
- **RISK** : détail XLSX/externe non capturé. **READABILITY** : moyenne à forte ; éviter un fichier par contrôle.

## T13 — Orchestration `main.R`

- **SCOPE** : orchestration et disparition des globaux ; **LEGACY COMPONENT** : `main.R:4-169` ; **TARGET RESPONSIBILITY** : `run_main_pipeline(config)` et `main.R` court.
- **BEHAVIOURS AFFECTED (IDs Axx)** : A01–A03, A23–A27.
- **TESTS REQUIRED BEFORE** : Golden Master, T01–T12, session propre et reprise.
- **IMPLEMENTATION STRATEGY** : remplacer `source()` métier par retours de listes nommées en conservant ordre et branches.
- **COMPARISON LEGACY / NEW** : end-to-end indépendant, logs et artefacts.
- **ROLLBACK POINT** : ancien `main.R` et workspace séparé. **EXIT CRITERIA** : Golden Master identique.
- **RISK** : dépendance globale oubliée. **READABILITY** : gain maximal.

## T14 — Suppression finale de S4

- **SCOPE** : `NR`, `setGeneric`, `setMethod`, slots et mécanismes inutiles ; **LEGACY COMPONENT** : infrastructure S4 active ; **TARGET RESPONSIBILITY** : fonctions ordinaires validées.
- **BEHAVIOURS AFFECTED (IDs B01–B04 ; contrôle A01–A27)**.
- **TESTS REQUIRED BEFORE** : tous les tests, Golden Master final, recherche statique et session propre.
- **IMPLEMENTATION STRATEGY** : `do.call(get(...))` après T07 ; génériques/méthodes par responsabilité après bascule ; ventilation après T08 ; post-traitements après T09 ; slots et `NR` en dernier après T11/T12 et zéro consommateur actif.
- **COMPARISON LEGACY / NEW** : comparaison complète et recherche d'`object@`, `setGeneric`, `setMethod`, `do.call(get(...))` dans le chemin baseline.
- **ROLLBACK POINT** : dernier état validé avec adaptateurs S4.
- **EXIT CRITERIA** : tous Axx passent, Golden Master identique, seuls B ont disparu.
- **RISK** : dépendance indirecte supprimée. **READABILITY** : maximale sans nouvelle indirection.

## Interfaces physiques et lisibilité

Les responsabilités de `TO_BE.md` ne sont pas une arborescence imposée. Pour la
taille du projet, elles peuvent être regroupées dans quelques fichiers lisibles :
`main.R`, un module imports/ETL, un module imputation, un module
ventilation/post-traitement, un module I/O/cache et un module contrôles/CNIV.

Les interfaces ordinaires restent explicites :

```r
identify_nonrespondents(sample, endogenous, date)
select_method(data, flow, regime, prediction_period, ref_period,
              endo_name, exogenous = NULL, er = NULL, nb_learning_year = 5)
estimate_imputation(data, method, prediction_period, learning_first, options)
apply_estimation_fallbacks(prediction, data, fallback_options)
normalize_predictions(prediction, na_imput = TRUE, negative_imput = TRUE)
distribute_predictions(estimation, detail_data, endo_name, periods, options)
run_introduction(inputs, options)
run_expedition(inputs, options)
run_main_pipeline(config)
```

Aucune factory, registry complexe, R6 ou métaprogrammation de remplacement ne
doit être introduite.

## Rollback et acceptation

- legacy exécutable jusqu'à T14 ;
- chaque tranche désactivable indépendamment ;
- aucune extraction combinée à un changement de format output ;
- arrêt sur divergence Axx inexpliquée ;
- aucune question métier ne justifie un écart de première migration.

Acceptation finale : Golden Master, A01–A27, outputs et artefacts observables
identiques ; éléments C reproduits ; `NR`, ses génériques/méthodes et
`do.call(get(...))` ne portent plus de comportement nécessaire à `main.R`.
