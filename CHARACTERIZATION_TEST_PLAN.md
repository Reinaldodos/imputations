# Plan de tests de caractérisation

## Principe

Les tests comparent l'ancien chemin actif `main.R` et la première cible sur les
mêmes fixtures, paramètres et état filesystem. Un comportement surprenant est
un oracle à reproduire, pas une erreur à corriger dans cette phase.

## Fixtures communes

- tibbles minimaux avec `siren`, `period`, endogène, exogène, ER et détail de
  ventilation ;
- périodes contiguës et non contiguës ;
- sirens nouvelles, historiques courts et historiques longs ;
- régimes 21 et 29 séparés puis consolidés ;
- états filesystem : aucun artefact, artefact complet, artefact partiel,
  cache existant ;
- fixtures de fichiers CSV2, RDS, Arrow, Parquet et CNIV.

## Unit tests

| ID | Sujet | Oracle |
|---|---|---|
| U01 | `get_NR_list()` | mêmes sirens non-répondantes et périodes |
| U02 | calcul `nobs` | même fenêtre avant un an et même comptage positif |
| U03 | seuil | décision identique pour `<`, `=` et `>` `12 * nb_learning_year` |
| U04 | introduction sans historique + exogène | `taking_exog` |
| U05 | introduction sans historique sans exogène | `taking_mean` |
| U06 | historique court sans exogène | `taking_last_year` |
| U07 | historique long sans exogène | `launch_sarima` |
| U08 | historique + exogène | `launch_reglin` |
| U09 | expédition 21 avec ER | priorité `taking_ER` pour les sirens/périodes concernées |
| U10 | expédition 21 sans ER | SARIMA ou M-12 selon profondeur |
| U11 | expédition 29 | jamais `taking_exog`, `taking_ER`, `taking_mean` ou `launch_reglin` dans la sélection initiale |
| U12 | `taking_exog` | jointure et libellé `method` identiques |
| U13 | `taking_ER` | jointure et libellé identiques |
| U14 | `taking_mean` | moyenne cumulée décalée identique |
| U15 | `taking_last_year` | jointure M-12 identique |
| U16 | fallback M-12 | passage à `taking_mean` si `alternative=TRUE` |
| U17 | SARIMA en erreur ou sans forecast | NA intermédiaire puis fallback M-12 |
| U18 | SARIMA NA/<=0 | fallback appliqué aux mêmes sirens |
| U19 | régression `lm`/`step` en erreur | NA puis fallback identique |
| U20 | régression NA/<=0 | fallback M-12 puis moyenne |
| U21 | normalisation | NA et négatifs mis à zéro selon options |
| U22 | méthode | `method_ref` et `method` conservés séparément |
| U23 | ratio | même `endo`, `sum_endo`, `ratio` |
| U24 | période précédente | même `period_last`, y compris période absente |
| U25 | ratio indéfini | même NA/erreur/ligne produite, sans correction |
| U26 | historique | mêmes lignes ajoutées et agrégées |
| U27 | Gazelec | mêmes sirens, lignes et branches optionnelles |
| U28 | MSD | mêmes couples siren/période supprimés |

## Characterization tests

### Sélection et fallbacks

Construire une table de cas couvrant toutes les combinaisons observables de
flux, régime, profondeur historique, exogène, ER et égalité
`ref_period == prediction_period`. Capturer :

- `method_ref` par siren ;
- `method` final par ligne ;
- prédiction avant et après normalisation ;
- comportement lorsque plusieurs sirens appartiennent à des méthodes
  différentes.

### Méthodes de calcul

- CA3 disponible pour une nouvelle entreprise ;
- ER présent seulement sur certaines périodes ;
- moyenne cumulée avec NA ;
- M-12 disponible, absent et non contigu ;
- SARIMA `try-error`, forecast absent, NA et <=0 ;
- régression `lm` échouée, `step` échoué, NA et <=0 ;
- chaîne exacte `M-12 → moyenne → zéro`.

### Régimes et ventilation

- calcul 21 et 29 séparé ;
- consolidation des prédictions et priorité des méthodes 21 ;
- ventilation globale appelée avec `vart_21` ;
- structure historique de la période précédente disponible ;
- première période sans précédent ;
- période précédente non contiguë ;
- `sum_endo = 0`, ratio NA et clé absente ;
- exports global, 21, 29 et ventilation distincts.

### Persistance

Pour chaque artefact actif, exécuter le scénario logique suivant avec fixtures :

```text
absence -> calcul -> écriture -> relecture
présence -> lecture sans recalcul
présence partielle -> comportement exact observé
```

## Integration tests

1. Exécuter la séquence complète `main.R` dans un workspace temporaire fixture.
2. Exécuter avec `ETL/` absent puis présent.
3. Exécuter avec `pipeline/` absent puis présent.
4. Vérifier l'enchaînement introduction → expédition → contrôles → CNIV.
5. Vérifier les écritures et relectures RDS/Arrow/Parquet.
6. Vérifier les branches Gazelec, historique et MSD.
7. Vérifier que les objets transmis entre étapes ont les mêmes colonnes,
   types, clés et périodes.

## Output regression tests

Comparer ancien/nouveau avec une comparaison structurée :

- fichiers CSV2 d'imputation et ventilation ;
- exports par régime 21/29 ;
- RDS de reprise et artefacts classés observables ;
- CSV médian CNIV ;
- XLSX CNIV et fichiers par confédération ;
- noms, chemins relatifs, colonnes, types, ordre, encodage, séparateur,
  représentations NA et zéros ;
- méthode et `method_ref`.

Les différences liées aux questions métier seront étiquetées et rapportées,
jamais corrigées par le test.

## Critères d'acceptation

- tous les cas de décision possèdent un oracle ;
- aucune branche active n'est couverte uniquement par un test de sortie globale ;
- les états filesystem sont testés séparément ;
- aucune assertion ne suppose une amélioration métier non décidée ;
- les sorties de référence sont reproductibles à inputs et état identiques.
