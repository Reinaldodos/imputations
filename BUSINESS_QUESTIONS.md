# Questions métier pour le service Diffusion

## Objet

Ce document isole les comportements actuellement observables mais dont
l'intention métier n'est pas démontrable par le dépôt. La première migration
doit les reproduire à l'identique. Aucune réponse ni correction n'est proposée
ici.

## Q01 — Ventilation expédition avec `vart_21`

### CURRENT BEHAVIOUR

Le résultat global expédition additionne les prédictions des régimes 21 et 29,
mais la ventilation active est appelée avec `expedition_21` et le détail
renommé `vart_21` (`programs/launch_expedition.R:34-55`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le code établit le mécanisme, pas la justification métier de l'utilisation de
la structure 21 pour un résultat global contenant aussi le régime 29.

### POTENTIAL IMPACT

La règle de ventilation, les totaux ventilés et les tests de référence peuvent
être différents selon l'intention attendue.

### DECISION FOR DIFFUSION

Confirmer si l'utilisation de `vart_21` pour le résultat global est une règle
métier validée.

## Q02 — Traitement du régime 29 dans la ventilation

### CURRENT BEHAVIOUR

Le régime 29 est estimé séparément et exporté séparément, mais aucun appel
direct de ventilation avec `expedition_29` n'est atteint depuis `main.R`.

### WHY IT IS QUESTIONABLE OR UNCLEAR

Il est impossible de déterminer si le régime 29 doit être ventilé directement,
avec la structure 21, ou uniquement conservé dans l'agrégation et l'export
spécifique.

### POTENTIAL IMPACT

Les sorties de ventilation 29 et les tests de non-régression sont concernés.

### DECISION FOR DIFFUSION

Définir le traitement métier attendu du régime 29 dans la ventilation.

## Q03 — `sum_endo = 0`

### CURRENT BEHAVIOUR

`distribution()` calcule `ratio = endo / sum_endo` sans garde explicite
(`programs/NR.R:1037-1043`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le résultat peut être manquant ou non exploitable, sans règle métier explicite
de redistribution ou d'arrêt.

### POTENTIAL IMPACT

Les totaux ventilés et les cas limites de production sont concernés.

### DECISION FOR DIFFUSION

Préciser le comportement métier attendu lorsque `sum_endo` est nul.

## Q04 — Période précédente absente

### CURRENT BEHAVIOUR

`period_last` est construite comme la période précédente disponible après tri,
et la première période n'a pas de période précédente (`NR.R:1044-1061`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le code ne définit pas de structure de remplacement lorsque la période
précédente est absente ou non contiguë.

### POTENTIAL IMPACT

Certaines lignes peuvent recevoir un ratio manquant et une ventilation
incomplète.

### DECISION FOR DIFFUSION

Définir le comportement attendu pour la première période et les périodes non
contiguës.

## Q05 — Clé historique de ventilation manquante

### CURRENT BEHAVIOUR

L'estimation est jointe à la structure historique par siren et `period_last`,
sans fallback explicite si la clé n'existe pas (`NR.R:1063-1075`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le code ne précise pas s'il faut conserver une NA, exclure la ligne,
redistribuer ou arrêter.

### POTENTIAL IMPACT

Les montants et la complétude des exports ventilés peuvent varier.

### DECISION FOR DIFFUSION

Définir le traitement d'une clé historique de ventilation absente.

## Q06 — Statut métier des ventilations et exports par régime

### CURRENT BEHAVIOUR

Des exports globaux, régime 21, régime 29 et ventilation sont produits dans
`launch_expedition.R:89-151`.

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le dépôt ne dit pas quels fichiers sont livrables, de contrôle ou seulement
intermédiaires.

### POTENTIAL IMPACT

Les contrats d'output et les critères d'acceptation de la production restent
ambigus.

### DECISION FOR DIFFUSION

Identifier les fichiers faisant foi pour la diffusion du chiffre.

## Q07 — Contrat des artefacts persistants

### CURRENT BEHAVIOUR

`main.R` lit des artefacts Arrow/Parquet et les fonctions NR lisent et écrivent
des RDS de reprise (`main.R:57-138`, `NR.R:953-1382`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le code ne distingue pas formellement interface persistante, historique et
cache supprimable.

### POTENTIAL IMPACT

La conservation, la reprise et les tests d'équivalence peuvent être mal
définies.

### DECISION FOR DIFFUSION

Classer les artefacts selon leur statut métier et leur durée de conservation.

## Q08 — Validité d'un cache existant

### CURRENT BEHAVIOUR

La présence d'un dossier ou fichier suffit à déclencher la relecture ; aucun
contrôle de date, paramètre, hash ou mtime n'est codé.

### WHY IT IS QUESTIONABLE OR UNCLEAR

Un artefact présent peut être obsolète sans que le chemin actif le détecte.

### POTENTIAL IMPACT

Les résultats de référence peuvent dépendre de l'état antérieur du filesystem.

### DECISION FOR DIFFUSION

Définir la règle métier/opérationnelle de validité et de reconstruction des
artefacts existants.

## Q09 — Outputs faisant foi

### CURRENT BEHAVIOUR

Les contrôles PC relisent des CSV de `output_PC` et CNIV produit des CSV/XLSX
locaux et réseau (`Controles_imput_PC_yb.R:44-146`, `launch_cniv.R:36-81`).

### WHY IT IS QUESTIONABLE OR UNCLEAR

Les consommateurs externes et les critères humains d'acceptation ne sont pas
dans le dépôt.

### POTENTIAL IMPACT

Un fichier pourrait être considéré à tort comme secondaire ou obligatoire.

### DECISION FOR DIFFUSION

Définir les outputs requis pour déclarer une production valide.

## Q10 — Publication et copies externes

### CURRENT BEHAVIOUR

Des copies réseau sont documentées et certains appels de copie sont commentés
dans les launchers.

### WHY IT IS QUESTIONABLE OR UNCLEAR

Le code et la documentation ne suffisent pas à établir la procédure de
publication faisant foi.

### POTENTIAL IMPACT

La chaîne peut calculer correctement mais ne pas satisfaire le processus de
diffusion attendu.

### DECISION FOR DIFFUSION

Confirmer les copies, publications et validations externes obligatoires.

## Q11 — Relances partielles

### CURRENT BEHAVIOUR

L'ordre complet de `main.R` est séquentiel, mais aucune procédure de relance
partielle n'est définie dans le dépôt.

### WHY IT IS QUESTIONABLE OR UNCLEAR

Les artefacts réutilisables et les étapes relançables ne sont pas explicités.

### POTENTIAL IMPACT

Les incidents et reprises peuvent produire des résultats différents du chemin
complet.

### DECISION FOR DIFFUSION

Confirmer les scénarios de relance partielle officiellement supportés.
