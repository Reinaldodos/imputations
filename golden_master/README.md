# Golden Master T00

Ce répertoire contient uniquement le harnais et ses tests techniques. Il ne
contient aucune donnée de production et ne source jamais `main.R` pendant les
tests. `main.R` reste donc exécutable indépendamment et aucun fichier R métier
n'est modifié.

## Principe

Le Golden Master est une capture immuable d'une exécution legacy représentative
du chemin actif. La capture doit être réalisée par le service Diffusion dans un
workspace isolé, après validation de la fixture et de sa représentativité. Le
repository ne contient actuellement ni données opérationnelles ni artefacts
permettant de produire cette capture.

Le comparateur vérifie d'abord le contenu sémantique et la structure : noms,
colonnes, types lorsque le format le permet, ordre des lignes, valeurs,
`NA`, zéros, feuilles XLSX et schémas. Un hash binaire n'est utilisé que si un
manifest déclare explicitement un format déterministe ; les XLSX et les
artefacts Arrow ne sont jamais comparés par hash binaire.

## Fichiers

```text
golden_master.R                         # capture et comparateurs
tests/testthat/test-golden_master.R     # tests synthétiques du harnais
```

## Ce qui doit être fourni avant la capture

Dans un workspace privé hors du repository, fournir :

- une copie du dépôt au commit legacy validé ;
- un jeu d'inputs autorisé et représentatif, ou une fixture anonymisée validée ;
- la configuration exacte et les chemins de fixture correspondants ;
- les fichiers d'entrée échantillon, endogènes introduction/expédition,
  CA3, ER, détails de ventilation, Gazelec, MSD et nomenclatures CNIV ;
- les fichiers XLS/XLSX de référence, historiques et référentiels nécessaires ;
- les artefacts ETL/pipeline si la capture doit partir d'un état déjà préparé ;
- l'état filesystem initial, notamment présence/absence de `ETL/`, `pipeline/`
  et des caches RDS ;
- les versions R, Java et packages réellement validées ;
- la liste approuvée des fichiers produits à capturer.

Les chemins réseau et identifiants ne doivent pas être copiés dans la fixture.
Les chemins doivent être redirigés vers le workspace isolé sans modifier les
contenus lus. Une anonymisation n'est acceptable que si elle conserve les noms
et types de colonnes, clés, relations, périodes, valeurs positives/nulles/NA/
négatives, régimes 21/29, cas de fallback et structure de ventilation.

L'environnement local observé pour T00 est R 4.6.1. Il ne constitue pas la
version de production. Les scripts du dépôt référencent notamment tidyverse,
pacman, lubridate, rio, janitor, stringr, arrow, doParallel, rlang, zoo,
multidplyr, data.table, tsbox, RJDemetra, xlsx, openxlsx, readxl et testthat.
La disponibilité et les versions de ces packages, ainsi que Java pour les
exports concernés, doivent être confirmées par Diffusion.

## Capture

Depuis le workspace privé, adapter `artifact_paths` à la liste validée puis
exécuter une capture du legacy. Exemple de principe :

```r
source("/chemin/vers/imputations/golden_master/golden_master.R")

workdir <- "/workspace/legacy-fixture"
snapshot_dir <- "/workspace/golden-master-accepted"
artifact_paths <- c(
  "sorties/resultat.csv",
  "sorties/resultat.rds",
  "sorties/resultat.xlsx"
)

run_legacy <- function() {
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(workdir)
  stdout_file <- tempfile("legacy-stdout-")
  stderr_file <- tempfile("legacy-stderr-")
  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", normalizePath(file.path(workdir, "main.R"))),
    stdout = stdout_file,
    stderr = stderr_file
  )
  list(
    status = as.integer(status),
    stdout = readLines(stdout_file, warn = FALSE),
    stderr = readLines(stderr_file, warn = FALSE)
  )
}

capture_reference(
  workdir = workdir,
  snapshot_dir = snapshot_dir,
  artifact_paths = artifact_paths,
  run_legacy = run_legacy,
  metadata = list(
    commit = "A renseigner",
    runtime = R.version.string,
    fixture_id = "A renseigner",
    input_hashes = "A renseigner"
  )
)
```

La fonction refuse les chemins absolus et les chemins sortant du workspace.
Elle capture le statut, l'ordre observable via les logs, les métadonnées et les
artefacts explicitement listés. Elle échoue si un artefact déclaré manque ou si
le processus legacy retourne un statut non nul.

La capture finale doit aussi contenir, dans la liste approuvée, les artefacts
intermédiaires pertinents : listes de non-répondants, `method_ref`/`method`,
prédictions avant et après fallback, résultats 21/29/consolidés, ratios de
ventilation, historique, Gazelec, MSD, CSV2, RDS, Arrow/Parquet et CSV/XLSX.
Cette exhaustivité est une validation humaine : le harnais ne peut pas deviner
quels fichiers externes sont contractuels.

## Manifest et comparaison

Le manifest doit au minimum contenir `path` et `type`, avec des types parmi
`csv`, `rds`, `arrow`, `xlsx` et `file`. Pour un CSV, une colonne optionnelle
`keys` peut contenir un vecteur de noms de colonnes ou une chaîne séparée par
des virgules. Une colonne optionnelle `deterministic` peut documenter un hash
pour un CSV/TXT/TSV/JSON réellement déterministe ; elle ne doit pas être
utilisée pour XLSX ou Arrow.

```r
source("golden_master/golden_master.R")
manifest <- data.frame(
  path = c("sorties/resultat.csv", "sorties/resultat.rds"),
  type = c("csv", "rds"),
  keys = c("siren,period", NA_character_),
  stringsAsFactors = FALSE
)
result <- compare_artifact_tree(
  "/workspace/golden-master-accepted/artifacts",
  "/workspace/new-run/artifacts",
  manifest
)
if (!isTRUE(result$ok)) print(result$differences)
stopifnot(isTRUE(result$ok))
```

La comparaison binaire des fichiers génériques est limitée à la taille ; pour
les formats lisibles, la comparaison structurée est l'oracle. Les différences
de bytes internes d'un XLSX ne sont donc pas des écarts fonctionnels si les
feuilles et leurs contenus sont identiques.

## Vérification de complétude et sécurité

Avant acceptation, vérifier : statut legacy nul, logs présents, métadonnées
complètes, hash des inputs et outputs renseignés dans l'inventaire validé,
état filesystem avant/après documenté, et présence de chaque artefact attendu.
Comparer l'inventaire produit du workspace à la liste approuvée afin qu'aucun
output ne soit ignoré silencieusement.

Ne pas versionner de secrets, tokens, identifiants PostgreSQL, chemins réseau
personnels, données brutes ou logs contenant des informations confidentielles.
Le snapshot accepté doit rester immuable et stocké dans un emplacement privé,
hors du repository si son contenu n'est pas publiable.

## Tests techniques

Les tests de `tests/testthat/` utilisent seulement de petits objets synthétiques
créés dans des répertoires temporaires. Ils vérifient le comparateur et la
capture, mais ne démontrent pas la représentativité de la production et ne
lancent pas `main.R`.

```bash
Rscript -e "testthat::test_dir('golden_master/tests/testthat', reporter='summary')"
```
