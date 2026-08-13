# Business Logic As-is — `programs/NR.R`

## Périmètre et conventions

Ce rapport couvre exclusivement la phase 5 bis. Il décrit la logique
effectivement observable dans `programs/NR.R`, `programs/launch_introduction.R`
et `programs/launch_expedition.R`.

- **FAIT OBSERVÉ** : directement établi par une expression de code.
- **INFÉRENCE** : interprétation cohérente mais non démontrée par le code.
- **INCONNU** : intention ou comportement impossible à établir statiquement.
- Les commentaires servent de contexte ; les conditions exécutables font foi.

Le pipeline n'a pas été exécuté. Aucun fichier de code ni `AS_IS.md` n'est
modifié par cette phase.

## 1. Modèle métier porté par `NR`

### 1.1 Paramètres conceptuels

Un objet `NR` représente un flux et une série endogène à imputer. Ses données
et paramètres sont stockés dans les slots définis dans `programs/NR.R:24-55` :

| Slot | Rôle métier observé | Exemples |
|---|---|---|
| `endogenous` | historique de la variable à imputer | `vart`, `vart_21`, `vart_29` |
| `endo_name` | nom de la variable endogène | `vart`, `vart_21`, `vart_29` |
| `exogenous` | série externe utilisable par certaines méthodes | CA3 |
| `exog_name` | nom de l'exogène | `medoc_0031` |
| `ER` | états récapitulatifs externes | ER expédition |
| `ER_name` | nom de la variable ER | `vfte` |
| `flow` | flux métier | `I` ou `E` |
| `reg_exped` | régime d'expédition | `0`, `21`, `29` |

La validité S4 impose notamment : endogène et noms de variables présents,
`flow` égal à `I` ou `E`, régime `0` pour l'introduction, et ER présent pour
le régime expédition 21 (`NR.R:61-109`).

### 1.2 Instanciations actives

| Instance | Construction | Endogène | Exogène | ER | Régime |
|---|---|---|---|---|---|
| Introduction | `launch_introduction.R:7-13` | `vart` | CA3 `medoc_0031` | non | `I`, 0 |
| Expédition 29 | `launch_expedition.R:7-11` | `vart_29` | non | non | `E`, 29 |
| Expédition 21 | `launch_expedition.R:13-19` | `vart_21` | non dans le slot `exogenous` | ER `vfte` | `E`, 21 |

Pour l'expédition 21, le slot `exogenous` n'est pas fourni ; l'ER est fourni
séparément et sert à `taking_ER`. La validité S4 contrôle la présence de
`ER`, mais le commentaire et les appels donnent la règle de sélection.

## 2. Politique de sélection dans `estimNR()`

Référence principale : `programs/NR.R:632-835`.

### 2.1 Variables de décision

Pour chaque `siren`, `estimNR()` calcule principalement :

- `nobs` : nombre de lignes historiques avant
  `min(prediction_period) - 1 an`, avec endogène strictement positive dans la
  branche expédition 29 et dans la branche historique générique
  (`NR.R:667-676`, `714-724`) ;
- `notna_exog` : nombre de valeurs exogènes non manquantes dans la jointure
  endogène/exogène (`NR.R:742-756`) ;
- seuil de série longue : `12 * nb_learning_year`, par défaut 60 mois ;
- `ref_period == prediction_period` : comparaison directe des arguments
  `Date` reçus par `estimNR()` (`NR.R:708`).

Le code distingue trois grandes branches :

1. expédition régime 29 : branche prioritaire, indépendante de
   `ref_period` (`NR.R:662-706`) ;
2. expédition régime 21 ou référence égale à la période prédite :
   historique long/court, avec priorité ER pour certaines sirens
   (`NR.R:708-738`) ;
3. autre cas, notamment introduction avec période différente : décision selon
   profondeur historique et présence d'exogène (`NR.R:739-770`).

### 2.2 Table de décision observée

| Contexte | Condition par siren | Méthode de référence `method_ref` |
|---|---|---|
| Expédition 29 | `nobs >= 12 * nb_learning_year` | `launch_sarima` |
| Expédition 29 | `nobs < 12 * nb_learning_year` | `taking_last_year` |
| Expédition 21 ou `ref_period == prediction_period` | `nobs >= 12 * nb_learning_year` | `launch_sarima` |
| Expédition 21 ou `ref_period == prediction_period` | `nobs < 12 * nb_learning_year` | `taking_last_year` |
| Expédition 21 | siren présente dans `object@ER` pour une période de `prediction_period` | remplace la méthode précédente par `taking_ER` |
| Autre cas | `nobs == 0` et `notna_exog > 0` | `taking_exog` |
| Autre cas | `nobs == 0` et `notna_exog == 0` | `taking_mean` |
| Autre cas | `0 < nobs < 12 * nb_learning_year` et `notna_exog == 0` | `taking_last_year` |
| Autre cas | `nobs >= 12 * nb_learning_year` et `notna_exog == 0` | `launch_sarima` |
| Autre cas | toutes les autres combinaisons, notamment historique + exogène | `launch_reglin` |

La ligne `nobs == 0` est testée avant les lignes `nobs < seuil` et
`nobs >= seuil`. Dans cette branche générique, une série sans historique et
avec exogène est donc orientée vers `taking_exog`, tandis qu'une série sans
historique ni exogène est orientée vers `taking_mean`.

### 2.3 Cas particuliers par flux et régime

#### Introduction (`flow = I`, `reg_exped = 0`)

- Si `ref_period == prediction_period`, l'introduction suit la branche
  historique `launch_sarima`/`taking_last_year` et ne passe pas par la table
  exogène de la branche générique (`NR.R:708-731`).
- Si `ref_period != prediction_period`, elle suit la branche générique :
  - pas d'historique + CA3 disponible : `taking_exog` ;
  - pas d'historique + CA3 absent : `taking_mean` ;
  - historique court sans CA3 : `taking_last_year` ;
  - historique long sans CA3 : `launch_sarima` ;
  - cas restant, notamment historique avec CA3 : `launch_reglin`.
- L'instance active fournit bien CA3 `medoc_0031` (`launch_introduction.R:7-13`).

#### Expédition régime 21

- L'expédition 21 entre toujours dans la branche historique spéciale, car la
  condition est `ref_period == prediction_period` **ou**
  `flow == E & reg_exped == 21` (`NR.R:708-710`).
- La méthode de base est `launch_sarima` si le seuil historique est atteint,
  sinon `taking_last_year` (`NR.R:711-731`).
- Cette méthode est ensuite remplacée par `taking_ER` pour les sirens présentes
  dans `object@ER` sur les périodes prédites (`NR.R:733-738`).
- La présence d'ER ne modifie pas le choix des sirens absentes d'ER : elles
  conservent `launch_sarima` ou `taking_last_year`.

#### Expédition régime 29

- Le régime 29 entre toujours dans la première branche (`NR.R:662`).
- La profondeur historique est mesurée avec endogène positive et sans
  considération d'exogène/ER (`NR.R:665-680`).
- La méthode est `launch_sarima` pour historique long et
  `taking_last_year` pour historique court.
- Aucun choix `taking_exog`, `taking_ER`, `taking_mean` ou `launch_reglin` n'est
  sélectionné par cette branche.

### 2.4 Appel dynamique de la méthode sélectionnée

`estimNR()` regroupe les sirens par `method_ref`, récupère la fonction par son
nom avec `get(method_ref)`, puis l'appelle avec `do.call()`
(`NR.R:683-705`, `774-820`). Les signatures diffèrent selon la méthode :

| Méthodes | Arguments effectivement transmis |
|---|---|
| `taking_exog`, `taking_mean`, `taking_ER` | `object`, `prediction_period`, `siren_list` |
| `taking_last_year` | mêmes arguments + `alternative` |
| `launch_sarima` | `object`, `prediction_period`, `learning_first`, `siren_list`, `nbproc`, `alternative` |
| `launch_reglin` | `object`, `prediction_period`, `siren_list`, `nb_learning_year`, `nbproc`, `alternative` |

Après concaténation des résultats :

- `na_imput = TRUE` remplace les `prediction` manquantes par `0`
  (`NR.R:823-825`) ;
- `negative_imput = TRUE` remplace les prédictions négatives par `0`
  (`NR.R:826-827`) ;
- `get_method_ref = TRUE` joint à la sortie le choix initial par siren
  (`NR.R:829-831`).

Le choix `method_ref` est donc distinct du champ `method` produit par la
fonction exécutée. Un fallback peut modifier `method` sans modifier, sauf
effet de `get_method_ref`, la méthode de référence initialement choisie.

## 3. Spécification descriptive des méthodes

### 3.1 `taking_exog`

**INPUTS**

- objet `NR` ;
- périodes prédites ;
- liste de sirens.

**PRECONDITIONS**

- `object@exogenous` doit être disponible et contenir `object@exog_name` ;
- la méthode est sélectionnée génériquement lorsque `nobs == 0` et qu'au moins
  une valeur exogène non manquante est comptée.

**TRANSFORMATION**

1. filtre l'exogène et l'endogène sur les sirens demandées ;
2. joint les deux tables par `siren` et `period` ;
3. construit le produit cartésien siren × période prédite ;
4. joint la valeur de la colonne exogène sur cette grille ;
5. renomme cette colonne `prediction`.

**OUTPUT**

Tibble avec `siren`, `period`, `prediction` et `method = "taking_exog"`
(`NR.R:143-157`).

**FAILURE CONDITIONS**

- valeur exogène absente pour une clé siren/période : `prediction` reste
  manquante ;
- slot, colonne ou type incompatible : erreur de l'opération de jointure ou de
  sélection ; aucun `try()` local n'est observé.

**FALLBACK**

Aucun fallback interne. Les `NA` éventuels sont convertis en zéro par
`estimNR()` si `na_imput = TRUE`.

**SIDE EFFECTS**

Aucun I/O ni cache dans cette méthode.

### 3.2 `taking_ER`

**INPUTS**

- objet `NR` ;
- périodes prédites ;
- sirens.

**PRECONDITIONS**

- `object@ER` et `object@ER_name` doivent être disponibles ;
- dans le chemin actif, le choix est réservé aux sirens du régime 21
  présentes dans ER sur les périodes prédites (`NR.R:733-738`).

**TRANSFORMATION**

Même structure que `taking_exog`, mais la valeur jointe provient de
`object@ER[object@ER_name]` (`NR.R:180-192`).

**OUTPUT**

Tibble `siren`, `period`, `prediction`, `method = "taking_ER"`.

**FAILURE CONDITIONS**

- ER absent pour une clé : prédiction manquante ;
- slot ou colonne ER invalide : erreur hors fallback local.

**FALLBACK**

Aucun fallback interne. Les valeurs manquantes suivent la normalisation finale
de `estimNR()`.

**SIDE EFFECTS**

Aucun I/O ni cache.

### 3.3 `taking_mean`

**INPUTS**

- objet `NR` ;
- périodes prédites ;
- sirens.

**PRECONDITIONS**

- historique endogène accessible ;
- méthode sélectionnée principalement lorsque `nobs == 0` et qu'aucune
  exogène n'est disponible dans la branche générique.

**TRANSFORMATION**

1. construit la grille siren × périodes prédites ;
2. la joint à l'endogène ;
3. trie par siren et période ;
4. calcule `cummean.na()` sur l'endogène ;
5. applique `lag()` afin que l'estimation d'une période utilise les valeurs
   antérieures et non la valeur de la période elle-même ;
6. conserve les périodes demandées (`NR.R:227-246`).

`cummean.na()` renvoie une moyenne cumulée pour les valeurs non manquantes et
`NA` lorsque la valeur courante est manquante (`NR.R:205-215`).

**OUTPUT**

Tibble `siren`, `period`, `prediction`, `method = "taking_mean"`.

**FAILURE CONDITIONS**

- aucune valeur antérieure exploitable : estimation potentiellement `NA` ;
- erreurs de colonne/jointure : aucune capture locale.

**FALLBACK**

Aucun fallback interne. Une estimation manquante devient zéro dans `estimNR()`
si `na_imput = TRUE`.

**SIDE EFFECTS**

Aucun I/O.

### 3.4 `taking_last_year`

**INPUTS**

- objet `NR` ;
- périodes prédites ;
- sirens ;
- `alternative`, par défaut `TRUE`.

**PRECONDITIONS**

- aucune profondeur minimale explicite dans la fonction ;
- la méthode est initialement attribuée aux historiques courts ou utilisée
  comme fallback des modèles.

**TRANSFORMATION**

1. pour chaque période prédite, calcule `last_year = period - 1 an` ;
2. joint l'endogène à cette période passée ;
3. renomme la valeur endogène en `prediction` ;
4. si `alternative = TRUE`, sélectionne les sirens dont la valeur est `NA` ;
5. calcule pour ces sirens `taking_mean` ;
6. remplace les lignes manquantes par le résultat de `taking_mean`
   (`NR.R:274-303`).

**OUTPUT**

Tibble `siren`, `period`, `prediction`, `method`. Le libellé peut donc être
`taking_last_year` ou `taking_mean` selon le remplacement effectué.

**FAILURE CONDITIONS**

- absence d'observation exactement à M-12 : la valeur est `NA` ;
- absence de moyenne de remplacement : la valeur reste `NA` ;
- erreur de jointure ou de colonne : non capturée localement.

**FALLBACK**

`taking_mean` pour les sirens/périodes sans valeur M-12 lorsque
`alternative = TRUE`.

**SIDE EFFECTS**

Aucun I/O.

### 3.5 `launch_sarima`

**INPUTS**

- objet `NR` ;
- période ou périodes prédites ;
- début de fenêtre d'apprentissage ;
- sirens ;
- nombre de processus ;
- `alternative`, par défaut `TRUE`.

**PRECONDITIONS**

- la sélection normale exige `nobs >= 12 * nb_learning_year` ;
- l'endogène doit pouvoir former une série temporelle mensuelle ;
- packages `tsbox`, `RJDemetra`, `doParallel` disponibles.

**TRANSFORMATION**

Pour chaque siren, en parallèle :

1. construit les mois de `learning_first` jusqu'au mois précédant la première
   prédiction ;
2. joint l'endogène ;
3. convertit en série temporelle ;
4. crée une spécification RegARIMA X13 `RG3` ;
5. appelle `regarima()` ;
6. transforme les prévisions en lignes siren/période.

Les erreurs de `regarima()` capturées par `try()` et les modèles sans forecast
produisent des prédictions `NA` (`NR.R:364-391`).

**OUTPUT**

Tibble `siren`, `period`, `prediction`, `method = "launch_sarima"`.

**FAILURE CONDITIONS**

- `regarima()` renvoie `try-error` ;
- forecast nul ;
- prédiction `NA` ou `<= 0` après production ;
- erreur de construction de série, cluster ou données hors des `try()` : non
  couverte par le fallback observé.

**FALLBACK**

Lorsque `alternative = TRUE`, `taking_last_year` est appliqué aux sirens dont
au moins une prédiction est `NA` ou `<= 0` (`NR.R:399-415`). Ce dernier peut
ensuite utiliser `taking_mean` pour les absences M-12.

**SIDE EFFECTS**

- création et arrêt d'un cluster parallèle (`NR.R:340-395`) ;
- enregistrement du backend `doParallel` ;
- aucun fichier écrit directement par cette méthode.

### 3.6 `launch_reglin`

**INPUTS**

- objet `NR` avec endogène et exogène ;
- périodes prédites ;
- sirens ;
- nombre d'années d'apprentissage ;
- nombre de processus ;
- `alternative`.

**PRECONDITIONS**

- la branche générique l'utilise notamment lorsque l'historique existe et que
  l'exogène est présente (`NR.R:757-766`) ;
- `object@exog_name` doit être exploitable ;
- données temporelles et variables saisonnières attendues doivent être
  disponibles.

**TRANSFORMATION**

1. étend la plage de prédiction jusqu'à au moins un an (`NR.R:474-477`) ;
2. joint endogène et exogène ;
3. limite les données à la fenêtre d'apprentissage ;
4. crée des indicatrices `july`, `august1`, `august2`, `september` selon les
   valeurs exogènes ;
5. remplace les valeurs manquantes de la série par zéro dans `create_ts()` ;
6. ajuste une régression linéaire endogène ~ exogène + indicatrices ;
7. applique une sélection backward avec `step()` ;
8. prédit les périodes futures ;
9. filtre finalement les périodes demandées (`NR.R:488-623`).

**OUTPUT**

Tibble `siren`, `period`, `prediction`, `method`. En cas de succès, le libellé
initial est `launch_reglin`; après fallback, il peut devenir
`taking_last_year` ou `taking_mean`.

**FAILURE CONDITIONS**

- échec de `lm()` ;
- échec de `step()` ;
- prédiction `NA` ou `<= 0` ;
- erreur de données, de variables ou d'exécution parallèle hors des `try()`.

**FALLBACK**

`taking_last_year` pour les sirens avec prédiction `NA` ou `<= 0`
(`NR.R:607-620`), puis éventuellement `taking_mean` dans cette méthode.

**SIDE EFFECTS**

- création et arrêt d'un cluster parallèle ;
- `print(data)` dans le worker (`NR.R:552`) ;
- enregistrement du backend parallèle ;
- aucun fichier écrit directement.

## 4. Graphe des fallbacks

### 4.1 Sélection initiale dans `estimNR()`

```text
FLOW = E et REGIME = 29
  |
  +-- nobs >= 12 * nb_learning_year --> launch_sarima
  |
  \-- nobs <  12 * nb_learning_year --> taking_last_year

Sinon, REF_PERIOD = PREDICTION_PERIOD
     ou FLOW = E et REGIME = 21
  |
  +-- nobs >= 12 * nb_learning_year --> launch_sarima
  |
  \-- nobs <  12 * nb_learning_year --> taking_last_year
       |
       \-- si E/21 et siren présente dans ER à la période prédite
           remplacement du choix par taking_ER

Sinon, branche générique
  |
  +-- nobs = 0 et notna_exog > 0 --> taking_exog
  |
  +-- nobs = 0 et notna_exog = 0 --> taking_mean
  |
  +-- nobs < seuil et notna_exog = 0 --> taking_last_year
  |
  +-- nobs >= seuil et notna_exog = 0 --> launch_sarima
  |
  \-- autre combinaison --> launch_reglin
```

### 4.2 Fallbacks d'exécution

```text
taking_exog
  |
  \-- prediction NA --> estimNR : 0 si na_imput = TRUE

taking_ER
  |
  \-- prediction NA --> estimNR : 0 si na_imput = TRUE

taking_mean
  |
  \-- prediction NA --> estimNR : 0 si na_imput = TRUE

taking_last_year
  |
  +-- M-12 disponible --> valeur M-12
  |
  \-- M-12 absent et alternative = TRUE --> taking_mean
                                      |
                                      \-- NA persistante --> 0 si na_imput

launch_sarima
  |
  +-- modèle sans forecast ou try-error --> NA
  +-- prediction NA ou <= 0 et alternative = TRUE
  |                                      |
  |                                      v
  \--------------------------------> taking_last_year
                                           |
                                           \-- M-12 absent --> taking_mean

launch_reglin
  |
  +-- lm/step échoue --> NA
  +-- prediction NA ou <= 0 et alternative = TRUE
  |                                      |
  |                                      v
  \--------------------------------> taking_last_year
                                           |
                                           \-- M-12 absent --> taking_mean

Après toute méthode
  |
  +-- NA et na_imput = TRUE --> 0
  \-- valeur négative et negative_imput = TRUE --> 0
```

**FAIT OBSERVÉ —** Le code ne définit pas de fallback de modèle pour les
erreurs survenues en dehors des `try()` locaux. Il ne réessaie pas
`launch_reglin` après échec de `launch_sarima`; la chaîne observée passe par
`taking_last_year`, puis éventuellement `taking_mean`.

## 5. Logique de ventilation

Références : `NR.R:984-1170`.

### 5.1 Entrée de la ventilation

`launch_distribution()` filtre d'abord `imput_result` sur la période demandée,
puis sélectionne dans `detail_data` les colonnes :

```text
siren, period, a129, nc8, pyod, payp, dept,
temo, natr, regdem, conf, object@endo_name
```

Le nom de la variable endogène est dynamique (`NR.R:1107-1125`). La
ventilation est donc paramétrée par le flux/régime via `object@endo_name`.

### 5.2 Choix de la structure historique

Dans `distribution()` :

1. `group` vaut toutes les colonnes de `data_distribution` sauf la variable
   endogène lorsque `ventil_imput == "all"` (`NR.R:1008-1017`) ;
2. les données sont regroupées par cette structure et par `siren`, `period` ;
3. l'endogène est agrégée en `endo = sum(endogène, na.rm = TRUE)`
   (`NR.R:1029-1034`) ;
4. pour chaque siren et période historique, le total `sum_endo` est calculé ;
5. le ratio est `ratio = endo / sum_endo` (`NR.R:1037-1043`) ;
6. les périodes présentes dans la structure historique sont combinées avec les
   périodes de l'estimation et triées par siren/période ;
7. `period_last` est la ligne précédente dans cet ordre (`NR.R:1044-1061`) ;
8. l'estimation courante est jointe à la structure dont la période est
   `period_last` (`NR.R:1063-1075`).

**FAIT OBSERVÉ —** La période historique utilisée est la période précédente
dans l'ordre des périodes disponibles pour la siren. Le code ne calcule pas
explicitement `prediction_period - 12 mois` dans `distribution()` et ne
garantit pas que les périodes soient contiguës.

### 5.3 Application du ratio

Pour une ligne d'estimation courante :

```text
dist_prediction = prediction * ratio
```

Le résultat conserve la clé de ventilation et les variables de contexte de la
structure historique (`NR.R:1067-1075`). Si `ventil_output` est fourni, les
lignes sont ensuite regroupées par période et cette colonne de sortie
(`NR.R:1077-1085`). Dans l'appel actif, `ventil_output` n'est pas fourni ; la
sortie détaillée est conservée.

**INCONNU —** Le code ne fournit pas de traitement explicite pour les ratios
indéfinis (`sum_endo = 0`), les clés historiques absentes ou les périodes sans
ligne précédente. Dans ces cas, la jointure peut produire des valeurs
manquantes ; aucune redistribution de secours n'est visible dans cette
fonction.

### 5.4 Reprise et persistance de la ventilation

`launch_all_distributions()` :

1. détermine `flow_name` (`intro` ou `exped`) ;
2. cherche `output_directory/{flow_name}_ventil.rds` ;
3. relit ce RDS s'il existe ;
4. sinon appelle `launch_distribution()` pour chaque date ;
5. concatène et sauvegarde le résultat (`NR.R:1149-1167`).

Le cache est partagé au niveau du flux (`intro_ventil.rds` ou
`exped_ventil.rds`), pas au niveau du régime expédition.

## 6. Introduction versus expédition

### Introduction

`launch_introduction.R:7-35` utilise :

- `NR(endogenous = endogenous_intro, endo_name = "vart", flow = "I")` ;
- exogène CA3 `medoc_0031` ;
- `detail_intro` pour la ventilation ;
- sélection de méthodes dépendant de la branche de `estimNR()` ;
- export d'une imputation et d'une ventilation d'introduction.

La structure de ventilation exclut la variable endogène `vart` des colonnes de
groupement lorsque `ventil_imput = "all"`, mais conserve les autres colonnes
de `detail_intro` transmises par `launch_distribution()`.

### Expédition

`launch_expedition.R:7-19` crée deux objets :

- régime 29 sur `vart_29`, sans exogène ni ER ;
- régime 21 sur `vart_21`, avec ER `vfte`.

Les deux estimations sont lancées séparément puis jointes par `siren` et
`period` (`launch_expedition.R:24-46`). Le résultat global `exped_imput` :

- additionne `prediction_21` et `prediction_29` ;
- conserve `method_21` si elle n'est pas manquante, sinon `method_29` ;
- conserve de même `method_ref_21` prioritairement.

La ventilation est ensuite lancée seulement avec `expedition_21` et un détail
où `vart` est renommée `vart_21` (`launch_expedition.R:50-55`). Le cache appelé
est donc celui du flux `exped`, non un cache 21/29 distinct.

## 7. Examen spécifique de l'observation A11

### Ce qui est établi statiquement

1. Les régimes 21 et 29 sont estimés séparément
   (`launch_expedition.R:24-33`).
2. Le résultat global d'imputation additionne leurs prédictions
   (`launch_expedition.R:34-46`).
3. La ventilation globale reçoit `exped_imput` global, mais l'objet `NR` passé
   à `launch_all_distributions()` est `expedition_21`
   (`launch_expedition.R:50-55`).
4. Le détail est renommé de `vart` vers `vart_21` avant la ventilation
   (`launch_expedition.R:54`).
5. `distribution()` utilise `object@endo_name` pour choisir la colonne
   endogène ; l'appel expédition utilise donc `vart_21`
   (`NR.R:1111-1124`).
6. Le régime 29 dispose ensuite de son propre passage `add_gazelec` et de son
   propre export rectifié (`launch_expedition.R:76-79`, `125-135`).
7. Le passage global `remove_msd()` utilise `expedition_21` comme objet, tandis
   que les passages par régime utilisent respectivement les objets 21 et 29
   (`launch_expedition.R:89-92`, `106-128`).

### Ce qui n'est pas établi

- Le code ne permet pas d'établir si l'utilisation de `vart_21` pour la
  structure de ventilation globale est une règle métier intentionnelle, une
  convention de données ou un reliquat historique.
- Le code ne permet pas d'établir si la prédiction du régime 29 est
  volontairement ventilée à l'aide de la structure 21, si les lignes de détail
  contiennent déjà une structure combinée, ou si le résultat global est utilisé
  seulement pour une sortie agrégée.
- Aucun traitement direct de ventilation `expedition_29` n'est appelé dans le
  chemin actif observé. Cela établit une absence d'appel, pas une anomalie.
- Le rôle exact des exports `exped_imput_21_rect`, `exped_imput_29_rect` et de
  l'export global dans le processus aval n'est pas déterminable à partir de
  ces seuls scripts.

### Qualification A11

**FAIT OBSERVÉ —** il existe une asymétrie d'implémentation entre estimation,
ventilation et exports des régimes 21/29.

**INCONNU —** l'intention métier et la conformité de cette asymétrie au
processus attendu ne sont pas démontrables statiquement.

Il n'est donc pas qualifié de bug dans ce rapport.

## 8. Règles métier versus mécanismes actuels

| RÈGLE MÉTIER OBSERVÉE | MÉCANISME D'IMPLÉMENTATION ACTUEL |
|---|---|
| Une série longue peut être estimée par SARIMA | méthode S4 `launch_sarima`, slot `endogenous`, `RJDemetra`, cluster parallèle |
| Une série courte utilise M-12 | `taking_last_year`, jointure sur `period - years(1)` |
| Une série sans historique peut utiliser une source externe | `taking_exog` ou `taking_ER`, sélection par `case_when` et `do.call(get(...))` |
| Une série récente sans source externe utilise une moyenne historique | `taking_mean` et `cummean.na()` |
| Une série avec historique et exogène peut utiliser une régression | `launch_reglin`, `lm`, `step`, variables saisonnières dynamiques |
| Une prédiction modèle invalide est remplacée | `alternative`, puis `taking_last_year`, puis `taking_mean` |
| Les sorties manquantes/négatives sont neutralisées | `na_imput` et `negative_imput` dans `estimNR()` |
| La ventilation reprend la structure d'une période antérieure | tri des périodes et création de `period_last` par `shift`/`rollapply` |
| La prédiction est répartie selon les proportions historiques | `ratio = endo / sum_endo`, puis multiplication par `prediction` |
| Les résultats peuvent être repris | `file.exists()`, `readRDS()`, `saveRDS()` |

## 9. Dépendances et effets de bord

### Objets S4 et slots

Les méthodes métier lisent directement les slots `NR` dans presque toutes les
étapes : `object@endogenous`, `object@endo_name`, `object@exogenous`,
`object@exog_name`, `object@ER`, `object@ER_name`, `object@flow` et
`object@reg_exped` (`NR.R:143-145`, `180-182`, `234`, `283`, `358-359`,
`489-491`, `662-766`, `1013-1124`).

Les fonctions d'orchestration ajoutent des dépendances au slot `Input`,
notamment `input@date_ref`, `input@output_directory`,
`input@historical_directory` et `input@date_publication`
(`NR.R:906`, `954`, `1191-1218`, `1420-1438`).

### Variables globales et chargement

- `source("programs/NR.R")` installe classes, génériques, méthodes et fonctions
  dans la session (`launch_introduction.R:4-5`, `launch_expedition.R:4-5`) ;
- les packages sont chargés par `pacman::p_load()` (`NR.R:1-9`) ;
- certaines fonctions utilisent des objets ou fonctions préparés ailleurs,
  par exemple `import_historique`, `import_gazelec`, `input_object`,
  `base_historique` et les fonctions d'export ;
- `do.call(get(method_ref), ...)` rend la sélection dépendante du nom de
  fonction présent dans l'environnement global.

### Filesystem et I/O

Les fonctions d'estimation et de ventilation sont appelées depuis des
wrappers qui écrivent des caches RDS :

- estimations : `NR.R:953-974` ;
- distributions : `NR.R:1149-1167` ;
- historique ajouté : `NR.R:1190-1239` ;
- Gazelec : `NR.R:1274-1325` ;
- suppression MSD : `NR.R:1359-1382`.

La fonction `export_to_historical_basis()` relit et peut réécrire
`Base_historique.rds` (`NR.R:1411-1440`), mais elle n'est pas appelée dans les
scripts actifs observés : l'appel commenté apparaît dans
`launch_expedition.R:156-157`.

### Parallélisme

`launch_sarima()` et `launch_reglin()` créent des clusters et enregistrent un
backend `doParallel` (`NR.R:340-395`, `479-603`). La fermeture du cluster est
explicitement appelée en cas de parcours nominal, mais un échec externe aux
blocs capturés peut laisser un état d'exécution non déterminé statiquement.

## 10. Référentiel des comportements à préserver

Ce référentiel décrit des invariants de comportement, sans proposer leur
réécriture.

### Sélection et estimation

1. Respecter les trois branches de priorité : expédition 29, expédition 21 ou
   période de référence égale, puis branche générique.
2. Utiliser le seuil exact `12 * nb_learning_year` et la fenêtre historique
   précédant d'un an la première période prédite.
3. Pour le régime 29, ne pas introduire implicitement de dépendance à l'exogène
   ou à l'ER : ce n'est pas utilisé par la branche observée.
4. Pour le régime 21, donner priorité à `taking_ER` uniquement aux sirens
   présentes dans ER pour les périodes prédites.
5. Préserver la distinction entre `method_ref` et `method`.
6. Préserver `taking_last_year` puis `taking_mean` comme chaîne de secours.
7. Préserver le critère modèle `NA` ou `<= 0` pour les fallbacks SARIMA et
   régression.
8. Préserver la normalisation finale des valeurs manquantes et négatives selon
   `na_imput` et `negative_imput`.
9. Préserver le mode `get_method_ref`, qui ajoute le choix de référence par
   siren.

### Ventilation

10. Utiliser les colonnes de structure transmises par `launch_distribution()`.
11. Exclure de la structure la variable endogène dynamique définie par
    `object@endo_name` lorsque `ventil_imput = "all"`.
12. Agréger l'endogène par siren, période et structure avant de calculer les
    proportions.
13. Calculer exactement `ratio = endo / sum_endo`.
14. Utiliser la période précédente disponible issue de l'ordre des données,
    sans supposer statiquement une période M-12.
15. Joindre l'estimation courante à la structure via `siren`, période courante
    et `period_last` historique.
16. Calculer exactement `dist_prediction = prediction * ratio`.
17. Préserver l'absence de fallback explicite pour ratios ou structures
    historiques manquants.
18. Préserver le cache de ventilation au niveau du flux (`intro`/`exped`).

### Différences introduction/expédition

19. Préserver `vart`/CA3 `medoc_0031` pour l'introduction.
20. Préserver `vart_21`/ER `vfte` pour l'expédition 21.
21. Préserver `vart_29` sans exogène/ER pour l'expédition 29.
22. Préserver l'agrégation des prédictions 21 et 29 dans `exped_imput`.
23. Préserver la priorité de la méthode 21 lors de la consolidation globale.
24. Préserver le fait que la ventilation expédition active est lancée avec
    `expedition_21` et le détail renommé `vart_21`.
25. Préserver séparément les exports globaux, régime 21 et régime 29 tels
    qu'ils sont appelés, sans déduire une intention non démontrée.

## Conclusion de phase 5 bis

**FAIT OBSERVÉ —** `estimNR()` sélectionne les méthodes par siren selon le
flux, le régime, la période de référence, la profondeur historique et la
présence de sources externes. Les modèles SARIMA et régression ont une chaîne
de secours vers M-12 puis moyenne historique.

**FAIT OBSERVÉ —** La ventilation applique des ratios construits sur la période
précédente disponible dans la structure historique, puis les multiplie par
l'estimation courante.

**FAIT OBSERVÉ —** L'expédition estime les régimes 21 et 29 séparément, les
consolide pour le résultat global, puis utilise l'objet et la variable du
régime 21 pour la ventilation active.

**INCONNU —** La justification métier de cette asymétrie et le rôle aval exact
de chaque export ne sont pas établis par le code statiquement.

Ce rapport s'arrête après la phase 5 bis. Aucune architecture To-be et aucune
modification de code ne sont incluses.
