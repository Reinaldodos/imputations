# Diagnostic de rationalisation technique

## Cadre

Les propositions ci-dessous ne corrigent aucune règle métier. Elles visent à
rendre la chaîne lisible par un utilisateur R, sous réserve que les tests de
caractérisation démontrent l'équivalence.

## R01 — Remplacer l'objet S4 `NR`

### CURRENT MECHANISM

Classe S4 `NR`, slots `endogenous`, `exogenous`, `endo_name`, `exog_name`, `ER`,
`ER_name`, `flow`, `reg_exped` (`programs/NR.R:24-120`).

### PROPOSED MECHANISM

Liste nommée explicite ou paramètres regroupés dans une liste simple, passée aux
fonctions ordinaires.

### BEHAVIOUR PRESERVED

Même sélection de flux/régime, mêmes colonnes endogènes/exogènes/ER et mêmes
résultats. L'absence de données, les NA et les valeurs étranges restent
identiques.

### TEST PROVING EQUIVALENCE

U02–U11 et comparaison des objets de décision avec les mêmes fixtures.

### BLAST RADIUS

Toutes les méthodes `NR`, `estimNR()`, `distribution()` et les launchers.

### RISK

Perte implicite d'une validation S4 ou d'un slot utilisé indirectement.

### READABILITY GAIN

Les entrées et sorties sont visibles dans les signatures et ne dépendent plus
d'accès par slot.

## R02 — Remplacer génériques et méthodes S4

### CURRENT MECHANISM

`setGeneric()`/`setMethod()` pour estimation, ventilation, historique, Gazelec
et MSD.

### PROPOSED MECHANISM

Fonctions R ordinaires : `select_method()`, `estimate_with_method()`,
`apply_estimation_fallbacks()`, `distribute_predictions()`.

### BEHAVIOUR PRESERVED

Même dispatch conceptuel, mêmes arguments effectifs, mêmes libellés `method` et
`method_ref`, mêmes effets de persistance placés à l'extérieur.

### TEST PROVING EQUIVALENCE

U12–U28 et integration tests du chemin complet.

### BLAST RADIUS

Modules `NR`, launchers introduction/expédition, CNIV et contrôles dépendants.

### RISK

Un dispatch implicite ou une validation S4 peut être oublié.

### READABILITY GAIN

Une fonction appelée montre directement le calcul exécuté.

## R03 — Remplacer `do.call(get(...))`

### CURRENT MECHANISM

`estimNR()` choisit un nom puis récupère et appelle dynamiquement la fonction
(`programs/NR.R:774-820`).

### PROPOSED MECHANISM

Décision explicite retournant un nom stable ou une fonction nommée dans une
table contrôlée, avec appel explicite par catégorie d'arguments.

### BEHAVIOUR PRESERVED

Ordre exact des branches, signatures, fallbacks et distinction `method_ref` /
`method`.

### TEST PROVING EQUIVALENCE

Table exhaustive de sélection et U16–U22.

### BLAST RADIUS

Uniquement sélection et appel des méthodes d'estimation.

### RISK

Modifier l'ordre de priorité ou la transmission de `alternative`/`nbproc`.

### READABILITY GAIN

La politique de décision devient lisible sans métaprogrammation.

## R04 — Séparer décision, calcul et normalisation

### CURRENT MECHANISM

`estimNR()` regroupe les sirens, appelle les méthodes, concatène et normalise
les sorties dans une même fonction.

### PROPOSED MECHANISM

Trois fonctions distinctes : décision par siren, calcul par méthode, puis
normalisation finale.

### BEHAVIOUR PRESERVED

Même regroupement, mêmes NA intermédiaires, mêmes fallbacks et mêmes zéros
finaux.

### TEST PROVING EQUIVALENCE

U02–U08, U16–U22 et tests de sortie par méthode.

### BLAST RADIUS

`estimNR()` et tous ses consommateurs.

### RISK

Déplacer trop tôt la mise à zéro et masquer la différence `method_ref`/`method`.

### READABILITY GAIN

Chaque étape a une responsabilité et un oracle séparé.

## R05 — Séparer calcul, cache et I/O

### CURRENT MECHANISM

Les méthodes d'orchestration testent `file.exists()`, lisent, calculent et
écrivent des RDS dans le même appel.

### PROPOSED MECHANISM

Fonctions pures de calcul plus wrappers explicites `read_cache()`,
`write_cache()` et `compute_or_read()` conservant les mêmes conventions.

### BEHAVIOUR PRESERVED

Même choix présence/absence, mêmes noms de fichiers, mêmes objets sauvegardés
et même absence de validation supplémentaire en première cible.

### TEST PROVING EQUIVALENCE

Scénarios filesystem absence → calcul → écriture et présence → lecture.

### BLAST RADIUS

ETL, pipeline et caches NR/post-traitement.

### RISK

Introduire une invalidation ou une validation nouvelle non autorisée.

### READABILITY GAIN

Les effets de bord sont repérables dans les wrappers I/O.

## R06 — Supprimer les dépendances globales

### CURRENT MECHANISM

Les `source()` créent des fonctions et objets utilisés implicitement par les
étapes suivantes.

### PROPOSED MECHANISM

Entrées explicites, retours de listes nommées et orchestration centrale.

### BEHAVIOUR PRESERVED

Même ordre, mêmes données transmises et mêmes paramètres de configuration.

### TEST PROVING EQUIVALENCE

Integration tests avec session propre et fixtures identiques.

### BLAST RADIUS

Tout le chemin `main.R`.

### RISK

Oublier un objet global utilisé indirectement par CNIV ou contrôles.

### READABILITY GAIN

Les dépendances deviennent inspectables par signature.

## R07 — Isoler le parallélisme

### CURRENT MECHANISM

`launch_sarima()` et `launch_reglin()` créent directement des clusters et
enregistrent `doParallel`.

### PROPOSED MECHANISM

Orchestration parallèle séparée du calcul d'une siren, avec worker testable
séquentiellement.

### BEHAVIOUR PRESERVED

Même calcul par siren, même ordre logique des résultats et mêmes fallbacks.

### TEST PROVING EQUIVALENCE

Comparaison séquentiel/parallèle sur fixtures et U17–U20.

### BLAST RADIUS

SARIMA et régression uniquement.

### RISK

Différences d'ordre, d'environnement worker ou de gestion d'erreur.

### READABILITY GAIN

Le calcul statistique est lisible sans gestion de cluster intégrée.

## R08 — Isoler exports et copies

### CURRENT MECHANISM

Les launchers mélangent calcul, écriture CSV/XLSX et copie réseau.

### PROPOSED MECHANISM

Writers et publishers séparés, avec formats et noms hérités explicitement.

### BEHAVIOUR PRESERVED

Même fichiers, noms, colonnes, séparateurs, NA, chemins et ordre d'appel.

### TEST PROVING EQUIVALENCE

Output regression tests et vérification des chemins de fichiers.

### BLAST RADIUS

Exports introduction, expédition, contrôles et CNIV.

### RISK

Changer un format ou publier un fichier à un moment différent.

### READABILITY GAIN

Les effets de sortie sont identifiables sans parcourir les calculs.

## R09 — Adaptateurs de persistance

### CURRENT MECHANISM

Les noms et formats RDS/Arrow/Parquet sont dispersés dans les scripts.

### PROPOSED MECHANISM

Adaptateurs I/O regroupant les chemins et formats existants, sans changer le
wire shape de première cible.

### BEHAVIOUR PRESERVED

Lecture/écriture des mêmes artefacts et reprises selon les mêmes conditions.

### TEST PROVING EQUIVALENCE

Regression des artefacts persistants et scénarios de cache.

### BLAST RADIUS

ETL, pipeline, NR, CNIV et contrôles.

### RISK

Transformer involontairement un cache en interface ou inversement.

### READABILITY GAIN

Les contrats I/O sont localisés et séparés de la logique métier.

## Contraintes de première cible

Les comportements suivants restent volontairement inchangés : la priorité des
méthodes et fallbacks, la mise à zéro des NA/négatifs, l'utilisation de
`vart_21`, l'absence de fallback de ventilation, les conventions de cache et
les différences d'exports par régime. Toute amélioration est renvoyée à
`BUSINESS_QUESTIONS.md`.
