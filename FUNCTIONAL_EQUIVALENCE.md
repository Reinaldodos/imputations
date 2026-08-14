# Référentiel d'équivalence fonctionnelle

## Périmètre

La baseline est le chemin actif atteignable depuis `main.R`. Les scripts non
atteignables sont hors compatibilité. La première cible doit reproduire les
comportements observables, y compris ceux listés comme questions métier.

## A — BEHAVIOUR TO PRESERVE

| ID | Comportement | Preuve | Observabilité | Effet attendu | Question associée | Test |
|---|---|---|---|---|---|---|
| A01 | `main.R` charge config, classes, ETL conditionnel, pipeline conditionnel, introduction, expédition, contrôles puis CNIV | `main.R:4-169` | élevée | même ordre et mêmes étapes | non | intégration séquentielle |
| A02 | ETL exécuté seulement si `ETL/` n'existe pas | `main.R:20-26` | élevée | lecture/recalcul identique selon dossier | cache | test dossier absent/présent |
| A03 | Pipeline exécuté seulement si `pipeline/` n'existe pas | `main.R:88-94` | élevée | mêmes artefacts lus ou reconstruits | cache | test dossier absent/présent |
| A04 | `get_NR_list()` sélectionne les sirens de l'échantillon du millésime applicable et absentes de l'endogène positive à la période | `NR.R:838-856` | élevée | même liste `siren`, `period` | non | unit test non-répondants |
| A05 | Seuil de série longue `12 * nb_learning_year` et fenêtre avant un an | `NR.R:662-766` | élevée | même `nobs` et même `method_ref` | non | table de décision |
| A06 | Expédition 29 : SARIMA si historique long, M-12 sinon | `NR.R:662-706` | élevée | mêmes méthodes | régime 29 | characterization 29 |
| A07 | Expédition 21 ou période de référence égale : SARIMA/M-12 puis priorité ER | `NR.R:708-738` | élevée | même sélection par siren | ventilation 21/29 | characterization 21 |
| A08 | Branche générique : exogène, moyenne, M-12, SARIMA ou régression selon `nobs` et `notna_exog` | `NR.R:739-770` | élevée | même décision | non | table exhaustive |
| A09 | `taking_exog` joint l'exogène sur siren/période et la renomme `prediction` | `NR.R:143-157` | élevée | même tibble et méthode | non | unit test |
| A10 | `taking_ER` joint l'ER sur siren/période | `NR.R:180-193` | élevée | même tibble et méthode | non | unit test |
| A11 | `taking_mean` utilise une moyenne cumulée décalée par `lag()` | `NR.R:205-246` | élevée | mêmes valeurs/périodes | non | unit test |
| A12 | `taking_last_year` utilise exactement la période M-12 | `NR.R:274-303` | élevée | mêmes valeurs | non | unit test |
| A13 | M-12 absent : fallback `taking_mean` si `alternative=TRUE` | `NR.R:289-301` | élevée | méthode effective identique | non | fallback test |
| A14 | SARIMA : erreur/forecast absent → NA, puis NA ou <=0 → M-12 | `NR.R:364-415` | élevée | mêmes prédictions et méthodes | non | mocks/characterization |
| A15 | Régression : erreur `lm`/`step` → NA, puis NA ou <=0 → M-12 | `NR.R:554-620` | élevée | mêmes prédictions et méthodes | non | mocks/characterization |
| A16 | `estimNR()` remplace les NA puis les valeurs négatives par zéro selon options | `NR.R:823-827` | élevée | mêmes zéros | non | unit test |
| A17 | `method_ref` reste distinct de `method` après fallback | `NR.R:778-831` | élevée | mêmes colonnes et libellés | non | output test |
| A18 | Expéditions 21/29 sont estimées séparément puis additionnées | `launch_expedition.R:24-46` | élevée | `prediction_21 + prediction_29` | régime 29 | characterization |
| A19 | La méthode 21 est prioritaire dans la consolidation globale si disponible | `launch_expedition.R:41-44` | élevée | même `method`/`method_ref` | régime 29 | unit test |
| A20 | Ventilation : agrégation historique, `ratio=endo/sum_endo`, structure de période précédente disponible | `NR.R:1029-1075` | élevée | mêmes ratios et `dist_prediction` | ratios | unit test |
| A21 | Ventilation expédition appelée avec `expedition_21` et détail renommé `vart_21` | `launch_expedition.R:50-55` | élevée | même asymétrie | Diffusion | characterization |
| A22 | Absence de fallback explicite pour ratio/structure manquants | `NR.R:1063-1075` | élevée | mêmes NA/états | Diffusion | edge cases |
| A23 | Mois historiques ajoutés avant Gazelec et MSD | `launch_introduction.R:40-76`, `launch_expedition.R:60-92` | élevée | même ordre et résultats | non | intégration |
| A24 | Gazelec appliqué selon options et régime | `NR.R:1272-1325` | élevée | mêmes sirens/lignes | Diffusion | unit/integration |
| A25 | MSD exclut les couples siren/période du flux | `NR.R:1356-1384` | élevée | mêmes lignes supprimées | non | unit test |
| A26 | Caches RDS relus si présents, sinon calculés puis écrits | `NR.R:953-974`, `1149-1167`, `1194-1238`, `1291-1325`, `1372-1382` | élevée | mêmes artefacts/branches | cache | filesystem tests |
| A27 | Exports CSV2, CNIV CSV/XLSX et copies appelées conservent formats, colonnes et noms | `NR.R:1393-1408`, `launch_cniv.R:36-81` | élevée | mêmes fichiers observables | outputs | regression |

## B — TECHNICAL MECHANISM REPLACEABLE

| ID | Mécanisme actuel | Remplacement possible sous condition |
|---|---|---|
| B01 | Classe S4 `NR` et slots | liste nommée ou arguments explicites, si les données et décisions sont identiques |
| B02 | `setGeneric()`/`setMethod()` | fonctions ordinaires nommées |
| B03 | `do.call(get(method_ref), ...)` | table de décision et dispatch explicite |
| B04 | objets globaux créés par `source()` | résultats retournés et transmis explicitement |
| B05 | calcul et écriture RDS dans les mêmes méthodes | couche cache/I-O séparée |
| B06 | clusters créés dans SARIMA/régression | orchestration parallèle isolée |
| B07 | noms internes `intro_imput`, `exped_imput_21`, etc. | structures nommées, si les outputs restent identiques |
| B08 | `source()` séquentiels | orchestration lisible, si l'ordre et les effets persistent |

## C — BUSINESS QUESTION FOR LATER

Ces éléments sont des comportements à reproduire en première cible, mais leur
intention pourra être réévaluée par Diffusion :

- ventilation du résultat global expédition incluant le régime 29 avec la
  structure `vart_21` ;
- absence d'appel direct de ventilation pour le régime 29 ;
- comportement des ratios indéfinis, périodes précédentes absentes et clés
  historiques manquantes ;
- statut contractuel exact des RDS, Arrow, Parquet et exports ;
- validité d'un artefact existant mais potentiellement obsolète.

## D — OUT OF SCOPE

- `launch_request.R`, `launch_production.R`, scripts `old/` et variantes non
  atteignables depuis `main.R` ;
- corrections ou améliorations de règles métier ;
- correction de l'asymétrie 21/29 ;
- traitement amélioré des ratios manquants ;
- optimisation de performance non requise pour l'équivalence.

## Critère global d'équivalence

Pour des inputs, paramètres et état filesystem identiques, la première cible
doit produire les mêmes objets observables, méthodes, NA/zéros, artefacts,
formats, chemins relatifs et sorties finales que le chemin actif de `main.R`.
