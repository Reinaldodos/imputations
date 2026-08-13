# Phase 5 ter — Résolution des inconnues

## 1. Périmètre et méthode

Ce rapport couvre les inconnues et questions ouvertes relevées dans
`AS_IS.md` et `BUSINESS_LOGIC_AS_IS.md`. L'analyse est statique : aucun
pipeline R n'a été exécuté et aucune donnée externe n'a été consultée.

Les états utilisés sont :

- **RÉSOLU STATIQUEMENT** : le dépôt permet de répondre précisément ;
- **PARTIELLEMENT RÉSOLU** : le code établit une partie du fait, mais pas son
  intention ou son usage opérationnel ;
- **À POSER À UN HUMAIN** : la réponse dépend de la production, de données
  externes ou d'une décision métier non présente dans le dépôt.

Les impacts décrivent les conséquences pour les travaux ultérieurs. Ils ne
constituent pas des propositions To-be.

## 2. Synthèse par criticité

### BLOCKER

- processus et entry point officiellement exécutés ;
- producteur officiel des inputs ;
- contrat des artefacts et caches ;
- règle métier de ventilation du résultat expédition incluant le régime 29 ;
- statut actif des identifiants PostgreSQL.

### IMPORTANT

- invalidation des caches ;
- statut des scripts hors chemin principal ;
- ordre de chargement externe ;
- disponibilité officielle des chemins réseau ;
- comportement attendu des cas limites de ventilation ;
- rôle aval des exports ;
- versions nécessaires à la reproductibilité opérationnelle.

### SECONDARY

- fonctions S4 historiques encore nécessaires selon les usages ;
- statut de support des fichiers anciens ;
- règles de production et version des inputs ;
- volumes et détails opérationnels non définis dans le dépôt.

## 3. Questions et résolutions détaillées

### OQ-01 — Entry point et ordonnancement réellement utilisés

- **ID** : OQ-01
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quel est l'entry point et l'ordonnancement officiellement
  utilisés en production aujourd'hui ?
- **SOURCE** : `AS_IS.md:350-352`, `AS_IS.md:687-689` ; `main.R:4-169`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : `main.R` est le seul entry point principal
  observable. Aucun ordonnanceur, workflow, CI/CD, Makefile, manifeste ou
  autre script d'appel n'est présent dans le dépôt. Les scripts hors de
  `main.R` ne peuvent pas être déclarés inexistants dans l'exploitation réelle.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quel est l'entry point et
  l'ordonnancement officiellement utilisés en production aujourd'hui ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : le processus documenté peut omettre
  des étapes ou inclure des étapes non exécutées.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests pourraient caractériser le
  mauvais scénario d'exécution.
- **IMPACT — ARCHITECTURE TO-BE** : les frontières d'exécution et les
  responsabilités externes resteraient indéterminées.
- **IMPACT — PLAN DE MIGRATION** : impossible de définir une séquence de
  remplacement fiable ni de choisir le point de bascule.

### OQ-02 — Fonctions S4 d'import encore nécessaires

- **ID** : OQ-02
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Quelles fonctions S4 d'import sont encore nécessaires au-delà
  de `Input(...)` et des appels CNIV ?
- **SOURCE** : `AS_IS.md:509-510` ; `programs/Input.R:270-862` ;
  `programs/NR.R:1202-1218,1273` ; `programs/launch_cniv.R:9-22` ;
  `Refactoring/prep pipeline.R:5-87`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les fonctions historiques sont encore appelées
  dans `Input.R`, `NR.R` et `launch_cniv.R`. Les fonctions fonctionnelles de
  `Refactoring/` sont aussi appelées par les préparations conditionnelles.
  Le dépôt établit donc une coexistence, mais pas quels appels sont utilisés
  dans tous les scénarios opérationnels.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Les appels S4 d'import de
  `Input.R` et `NR.R` sont-ils encore exécutés en production, ou seulement
  conservés pour des relances et compatibilités historiques ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : plusieurs chaînes d'import pourraient
  être considérées à tort comme une seule règle métier.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faudrait couvrir une chaîne
  historique et une chaîne `Refactoring` si les deux sont supportées.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces réellement contractuelles
  des imports ne sont pas identifiées.
- **IMPACT — PLAN DE MIGRATION** : le périmètre de remplacement des méthodes
  S4 ne peut pas être fermé.

### OQ-03 — Invalidation des caches

- **ID** : OQ-03
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Qui invalide les caches après changement de configuration ou
  d'input ?
- **SOURCE** : `AS_IS.md:521-522` ; `programs/NR.R:953-974,1149-1167,
  1190-1239,1291-1325,1372-1384` ; `main.R:20-26,88-94`.
- **ÉTAT** : RÉSOLU STATIQUEMENT pour le code, À POSER À UN HUMAIN pour la
  procédure opérationnelle
- **INVESTIGATION STATIQUE** : aucune invalidation par date, paramètres, hash,
  taille ou mtime n'est codée. `file.exists()` décide seul entre lecture et
  recalcul pour les caches RDS ; `dir.exists()` décide seul pour `ETL/` et
  `pipeline/`. Le dépôt ne montre aucun nettoyeur ou contrôle d'intégrité.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure opérationnelle
  supprime ou invalide les caches `ETL`, `pipeline` et `output_PC` après un
  changement d'input ou de paramètre ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les résultats peuvent dépendre d'un
  état persistant non déclaré.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests doivent distinguer premier
  calcul, reprise d'un cache valide et reprise d'un cache obsolète.
- **IMPACT — ARCHITECTURE TO-BE** : le rôle cache/interface des artefacts ne
  peut pas être défini uniquement par le code.
- **IMPACT — PLAN DE MIGRATION** : une migration pourrait réutiliser des
  artefacts incompatibles ou modifier silencieusement les résultats.

### OQ-04 — Scripts réellement utilisés hors `main.R`

- **ID** : OQ-04
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels scripts hors `main.R` sont encore supportés et exécutés ?
- **SOURCE** : `AS_IS.md:533-534,587-588` ; `main.R:154-160` ;
  `programs/launch_production.R`, `launch_request.R`, `programs/old/*`,
  `Controles_imput_C.R`, `CNIV_zero_mois.R`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : aucun de ces scripts n'est sourcé par le chemin
  principal. `launch_production.R` est explicitement commenté ;
  `launch_request.R` contient une chaîne PostgreSQL ; les scripts anciens
  contiennent des traitements autonomes. Leur support opérationnel n'est pas
  documenté.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels scripts hors `main.R` sont
  encore supportés, exécutés ou nécessaires aux relances de production ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : des sorties ou contrôles absents du
  chemin principal peuvent être requis par le processus réel.
- **IMPACT — TESTS DE CARACTÉRISATION** : le périmètre des scénarios à tester
  resterait incomplet.
- **IMPACT — ARCHITECTURE TO-BE** : impossible de distinguer les composants
  actifs des archives ou outils manuels.
- **IMPACT — PLAN DE MIGRATION** : risque de supprimer un flux encore utilisé.

### OQ-05 — Ordre de chargement externe

- **ID** : OQ-05
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : L'ordre de chargement est-il garanti par un ordonnanceur
  externe ou par une procédure manuelle ?
- **SOURCE** : `AS_IS.md:547-548` ; `main.R:4-169` ;
  `programs/launch_introduction.R:4`, `launch_expedition.R:4`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : dans le chemin visible, l'ordre est imposé par
  les `source()` séquentiels et les objets globaux. Aucun mécanisme externe ne
  figure dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « L'ordre `config` → ETL → pipeline
  → introduction → expédition → contrôles → CNIV est-il garanti par une
  procédure officielle, et existe-t-il des exécutions partielles autorisées ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la dépendance à l'ordre et aux objets
  de session peut être sous-documentée.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faut tester les démarrages propres
  et les relances partielles si elles sont autorisées.
- **IMPACT — ARCHITECTURE TO-BE** : les contrats entre étapes ne sont pas
  entièrement déterminables.
- **IMPACT — PLAN DE MIGRATION** : une migration non séquentielle pourrait
  changer les effets de bord et les résultats.

### OQ-06 — Chemins officiellement disponibles

- **ID** : OQ-06
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels chemins sont disponibles selon les régimes de
  production (local, VPN, partage, Kayzer) ?
- **SOURCE** : `AS_IS.md:559-560` ; `README.md:20-28,31-39` ;
  `config.R:66-117,163-199,315-364` ;
  `programs/Controles_imput_PC_yb.R:22-23`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les chemins codés et leurs rôles sont
  identifiables, notamment `input`, `output_PC`, lecteur `P:`, CA3 relatif et
  chemin SIRENE Windows. Leur disponibilité effective et les variantes par
  poste ne sont pas dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels chemins locaux, réseau,
  VPN et Kayzer sont officiellement requis et disponibles pour chaque étape de
  la production ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la définition des inputs et outputs
  opérationnels reste incomplète.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests de reproductibilité ne
  peuvent pas fixer un environnement cible.
- **IMPACT — ARCHITECTURE TO-BE** : les frontières I/O et les dépendances
  d'environnement restent ouvertes.
- **IMPACT — PLAN DE MIGRATION** : risque de rupture d'accès aux données ou aux
  exports lors du changement de poste ou d'exécution.

### OQ-07 — Processus opérationnel faisant foi

- **ID** : OQ-07
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quelle version du processus opérationnel fait foi ?
- **SOURCE** : `AS_IS.md:574-575` ; `README.md:8-18` ; commentaires et appels
  commentés dans `launch_introduction.R:78-86` et `launch_expedition.R:99-154`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : le README décrit des copies réseau et locales,
  tandis que plusieurs appels de copie réseau sont commentés dans le code.
  Aucun document opérationnel complet n'est présent dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure opérationnelle
  validée fait foi lorsque la documentation et les appels actifs/commentés
  divergent ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les outputs réellement contractuels
  peuvent être mal identifiés.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests pourraient valider des
  fichiers non livrés ou manquer des copies obligatoires.
- **IMPACT — ARCHITECTURE TO-BE** : les responsabilités de livraison et de
  publication restent indéterminées.
- **IMPACT — PLAN DE MIGRATION** : le critère de non-régression opérationnelle
  ne peut pas être défini.

### OQ-08 — Statut des scripts anciens et variantes

- **ID** : OQ-08
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Les scripts anciens doivent-ils être considérés comme
  supportés, archivés ou non utilisés ?
- **SOURCE** : `AS_IS.md:587-588,673-674` ; `programs/old/*`,
  `Controles_imput_C.R`, `CNIV_zero_mois.R`, scripts de production commentés.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : ces fichiers sont présents et définissent des
  fonctions ou traitements, mais aucun appel depuis `main.R` n'est observé.
  Le dépôt ne contient pas de marquage officiel de statut.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels fichiers de `programs/old/`
  et quelles variantes historiques sont officiellement hors support, et
  lesquels doivent rester exécutables pour les relances ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : le référentiel pourrait inclure ou
  exclure à tort des comportements historiques.
- **IMPACT — TESTS DE CARACTÉRISATION** : le nombre de scénarios et de sorties
  à conserver n'est pas fixé.
- **IMPACT — ARCHITECTURE TO-BE** : les frontières du périmètre de migration
  restent ambiguës.
- **IMPACT — PLAN DE MIGRATION** : risque de supprimer une capacité de reprise.

### OQ-09 — Producteur officiel des inputs PostgreSQL

- **ID** : OQ-09
- **CRITICITÉ** : BLOCKER
- **QUESTION** : `launch_request.R` est-il le producteur officiel des inputs
  CSV ?
- **SOURCE** : `AS_IS.md:611-612` ; `programs/launch_request.R:72-119`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : le script construit des requêtes PostgreSQL,
  lit `request_data` depuis la configuration et écrit les CSV dans les
  répertoires déclarés. Il n'est pas appelé par `main.R`.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « `launch_request.R` est-il encore
  le producteur officiel des inputs CSV, ou les fichiers sont-ils produits par
  une procédure externe ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la provenance, le filtrage et la
  fraîcheur des inputs restent incertains.
- **IMPACT — TESTS DE CARACTÉRISATION** : les fixtures pourraient ne pas
  reproduire la collecte officielle.
- **IMPACT — ARCHITECTURE TO-BE** : la frontière entre collecte et traitement
  n'est pas définie.
- **IMPACT — PLAN DE MIGRATION** : risque de migrer le traitement sans
  préserver le producteur d'inputs.

### OQ-10 — Statut des identifiants PostgreSQL

- **ID** : OQ-10
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Les identifiants PostgreSQL présents dans `launch_request.R`
  sont-ils actifs, révoqués ou purement historiques ?
- **SOURCE** : `AS_IS.md:621-622` ; `programs/launch_request.R:4-5`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : le dépôt contient des valeurs d'identifiant et
  de mot de passe en clair. Leur validité ne peut pas être déterminée sans
  vérification d'accès, qui est hors périmètre et non autorisée ici.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Les identifiants PostgreSQL de
  `programs/launch_request.R` sont-ils actifs, révoqués ou historiques, et
  quelle procédure officielle doit être utilisée pour leur remplacement ou
  leur retrait ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la disponibilité de la collecte par
  ce script ne peut pas être caractérisée.
- **IMPACT — TESTS DE CARACTÉRISATION** : aucun test ne doit dépendre d'un
  secret dont le statut est inconnu.
- **IMPACT — ARCHITECTURE TO-BE** : les exigences d'accès aux données restent
  indéterminées.
- **IMPACT — PLAN DE MIGRATION** : un secret actif, exposé ou révoqué peut
  modifier l'urgence et le périmètre de migration.

### OQ-11 — Versions d'inputs et règles de dépôt

- **ID** : OQ-11
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelles versions et règles de dépôt produisent les inputs
  opérationnels ?
- **SOURCE** : `AS_IS.md:599-600` ; `config.R:133-364` ; `README.md:20-28`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : les noms, périodes, répertoires et paramètres
  attendus sont codés. Les règles de génération, validation, dépôt et
  remplacement des fichiers externes ne le sont pas.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure produit, valide
  et dépose chaque input attendu, et comment sa version est-elle identifiée ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la définition d'un input valide reste
  incomplète.
- **IMPACT — TESTS DE CARACTÉRISATION** : impossible de fixer les fixtures et
  contrôles de fraîcheur attendus.
- **IMPACT — ARCHITECTURE TO-BE** : les contrats d'entrée ne sont pas
  spécifiables uniquement à partir des lecteurs R.
- **IMPACT — PLAN DE MIGRATION** : risque de changement simultané du producteur
  et du consommateur sans possibilité d'isoler les écarts.

### OQ-12 — Ventilation expédition du régime 29

- **ID** : OQ-12
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Quelle règle métier doit s'appliquer à la ventilation des
  prédictions expédition du régime 29 ?
- **SOURCE** : `AS_IS.md:635-636` ; `BUSINESS_LOGIC_AS_IS.md:668-704` ;
  `programs/launch_expedition.R:24-55,76-84,125-151`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : le régime 29 est estimé séparément et exporté
  séparément. Le résultat global additionne les régimes 21 et 29, mais la
  ventilation globale est appelée avec `expedition_21` et le détail renommé
  `vart_21`. Aucun appel direct de ventilation 29 n'est observé.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Les prédictions du régime 29
  doivent-elles être ventilées directement, ventilées avec la structure 21,
  ou rester uniquement dans l'export agrégé/par régime ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la règle de production des valeurs
  ventilées expédition n'est pas fermée.
- **IMPACT — TESTS DE CARACTÉRISATION** : les sorties 29 ventilées ne peuvent
  pas recevoir de valeur attendue fiable.
- **IMPACT — ARCHITECTURE TO-BE** : le contrat de ventilation par régime reste
  indéterminé.
- **IMPACT — PLAN DE MIGRATION** : risque de préserver ou de corriger une
  asymétrie sans savoir si elle est contractuelle.

### OQ-13 — Intention de l'utilisation de `vart_21`

- **ID** : OQ-13
- **CRITICITÉ** : BLOCKER
- **QUESTION** : La structure `vart_21` est-elle volontairement utilisée pour
  ventiler le résultat expédition global incluant le régime 29 ?
- **SOURCE** : `BUSINESS_LOGIC_AS_IS.md:683-684,720-723` ;
  `programs/launch_expedition.R:50-55` ; `NR.R:1108-1124`.
- **ÉTAT** : NON RÉSOLVABLE STATIQUEMENT
- **INVESTIGATION STATIQUE** : le choix technique est certain :
  `expedition_21` et `detail_exped` renommé `vart_21` sont transmis à la
  ventilation, tandis que `exped_imput` contient la somme des deux régimes.
  L'intention métier et la conformité attendue ne sont pas exprimées.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « L'utilisation de `vart_21` pour
  calculer les ratios de ventilation du résultat expédition global incluant le
  régime 29 est-elle une règle métier validée ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : il est impossible de déclarer cette
  asymétrie comme comportement requis ou anomalie.
- **IMPACT — TESTS DE CARACTÉRISATION** : les valeurs ventilées globales ne
  peuvent pas être comparées à une référence métier certaine.
- **IMPACT — ARCHITECTURE TO-BE** : les données de ventilation à exposer ne
  sont pas définies.
- **IMPACT — PLAN DE MIGRATION** : une conservation exacte et une correction
  éventuelle conduiraient à deux migrations différentes.

### OQ-14 — Rôle aval des exports

- **ID** : OQ-14
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quel est le rôle contractuel de chaque export global, régime
  21, régime 29 et ventilation dans les traitements aval ?
- **SOURCE** : `AS_IS.md:658-659` ; `BUSINESS_LOGIC_AS_IS.md:683-684` ;
  `launch_expedition.R:89-151` ; `Controles_imput_PC_yb.R:44-146`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les contrôles PC consomment les exports CSV
  trouvés dans `output_PC`. Le code établit les producteurs, mais ne définit
  pas le statut métier de chaque fichier ni les consommateurs externes.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels fichiers d'output sont
  contractuels pour les utilisateurs et quels fichiers sont seulement des
  artefacts intermédiaires ou de contrôle ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les sorties obligatoires ne sont pas
  toutes identifiées.
- **IMPACT — TESTS DE CARACTÉRISATION** : les assertions de non-régression ne
  peuvent pas hiérarchiser les fichiers.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces de sortie restent
  ambiguës.
- **IMPACT — PLAN DE MIGRATION** : risque de supprimer ou renommer un fichier
  consommé hors dépôt.

### OQ-15 — Cas limites des ratios de ventilation

- **ID** : OQ-15
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quel comportement est attendu lorsqu'aucune structure
  historique ou aucun ratio valide n'est disponible ?
- **SOURCE** : `BUSINESS_LOGIC_AS_IS.md:588-591` ; `NR.R:1029-1075`.
- **ÉTAT** : RÉSOLU STATIQUEMENT pour l'absence de fallback ; À POSER À UN
  HUMAIN pour le comportement attendu
- **INVESTIGATION STATIQUE** : `ratio = endo / sum_endo` est calculé sans
  garde explicite. La jointure sur `period_last` ne comporte pas de branche de
  secours. Le code ne définit donc ni redistribution, ni erreur métier, ni
  exclusion explicite de ces lignes.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Lorsqu'un ratio est indéfini,
  qu'une période précédente manque ou qu'une clé historique n'existe pas,
  faut-il produire une valeur manquante, exclure la ligne, redistribuer le
  total ou arrêter le traitement ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les règles de ventilation des cas
  limites restent incomplètes.
- **IMPACT — TESTS DE CARACTÉRISATION** : il manque des valeurs attendues pour
  les cas zéro, vide et première période.
- **IMPACT — ARCHITECTURE TO-BE** : les garanties de sortie ne peuvent pas
  être déduites.
- **IMPACT — PLAN DE MIGRATION** : un traitement explicite ultérieur pourrait
  changer les totaux sans qu'il soit possible de distinguer correction et
  régression.

### OQ-16 — Artéfacts : contrats ou caches

- **ID** : OQ-16
- **CRITICITÉ** : BLOCKER
- **QUESTION** : Les artefacts RDS/Arrow/Parquet sont-ils des contrats
  persistants ou des caches supprimables ?
- **SOURCE** : `AS_IS.md:658-659` ; `BUSINESS_LOGIC_AS_IS.md:724-735` ;
  `main.R:20-138` ; `NR.R:953-974,1149-1167`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : certains artefacts servent clairement de
  reprise (`*_imput.rds`, `*_ventil.rds`) et d'autres d'interface entre étapes
  (`ETL/*.arrow`, `pipeline/*`). Le code ne déclare pas formellement leur
  statut, durée de vie ou conservation réglementaire.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels artefacts doivent être
  conservés et versionnés comme interfaces ou historiques, et lesquels peuvent
  être supprimés puis recalculés ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la persistance fait partie ou non du
  comportement attendu selon une information absente.
- **IMPACT — TESTS DE CARACTÉRISATION** : il faut savoir si les tests portent
  sur les artefacts eux-mêmes ou seulement sur les outputs finaux.
- **IMPACT — ARCHITECTURE TO-BE** : les frontières entre données persistantes,
  cache et contrat restent indéterminées.
- **IMPACT — PLAN DE MIGRATION** : risque de perte d'historique ou de rupture
  de reprise lors du remplacement des formats.

### OQ-17 — Contrôle d'intégrité des dossiers ETL/pipeline

- **ID** : OQ-17
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Existe-t-il un contrôle d'intégrité externe ou une procédure
  de nettoyage/reconstruction complète des dossiers ETL et pipeline ?
- **SOURCE** : `AS_IS.md:647-648` ; `main.R:20-26,88-94` ;
  `Refactoring/import et prep.R:1-43` ; `Refactoring/prep pipeline.R:1-89`.
- **ÉTAT** : RÉSOLU STATIQUEMENT pour le dépôt ; À POSER À UN HUMAIN pour
  l'exploitation
- **INVESTIGATION STATIQUE** : le dépôt teste uniquement `dir.exists()`, sans
  contrôler la présence ou la cohérence de chaque fichier attendu. Aucun
  nettoyage ou reconstru​​ction complète n'est codé.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelle procédure est utilisée
  lorsqu'un dossier ETL ou pipeline existe mais est incomplet ou corrompu ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les conditions de reprise et de
  recalcul ne sont pas entièrement documentées.
- **IMPACT — TESTS DE CARACTÉRISATION** : les scénarios de dossiers partiels
  restent sans oracle métier.
- **IMPACT — ARCHITECTURE TO-BE** : les exigences d'atomicité et d'intégrité
  des étapes ne sont pas établies.
- **IMPACT — PLAN DE MIGRATION** : un changement de format peut laisser des
  dossiers mixtes non détectés.

### OQ-18 — Branches historiques et versions de R/packages

- **ID** : OQ-18
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quelles versions de R et des packages sont nécessaires pour
  reproduire le processus validé ?
- **SOURCE** : `AS_IS.md:673-674` ; `programs/NR.R:1-9` ; absence de
  `DESCRIPTION`, `renv.lock`, `packrat.lock` et manifeste équivalent.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les packages demandés sont visibles, mais aucune
  version n'est fixée. La compatibilité effective des branches historiques,
  de `RJDemetra`, `xlsx`, `arrow` et des APIs tidyverse n'est pas établie.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelles versions de R, Java et
  des packages sont validées pour la production et les relances historiques ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : des comportements observés peuvent
  dépendre de versions non documentées.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests pourraient être
  non-reproductibles entre environnements.
- **IMPACT — ARCHITECTURE TO-BE** : les contraintes de compatibilité restent
  ouvertes.
- **IMPACT — PLAN DE MIGRATION** : impossible d'attribuer avec certitude un
  écart à la migration ou à une variation de runtime.

### OQ-19 — Branches historiques effectivement exécutées

- **ID** : OQ-19
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Les branches historiques sont-elles encore exécutées, et avec
  quelles versions de R/packages ?
- **SOURCE** : `AS_IS.md:673-674` ; `programs/old/*`,
  `CNIV_zero_mois.R`, `Controles_imput_C.R`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : aucune atteinte depuis `main.R` n'est observée,
  mais l'absence d'appel interne ne prouve pas l'absence d'usage manuel ou
  externe.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quelles branches historiques
  sont encore exécutées, par qui, dans quel environnement et pour quelles
  sorties ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : des comportements de compatibilité
  pourraient manquer au référentiel.
- **IMPACT — TESTS DE CARACTÉRISATION** : des scénarios de relance pourraient
  être omis.
- **IMPACT — ARCHITECTURE TO-BE** : le périmètre de support reste trop large
  ou trop étroit.
- **IMPACT — PLAN DE MIGRATION** : risque de casser une procédure non
  référencée dans le dépôt.

### OQ-20 — Volumes et conditions d'exploitation

- **ID** : OQ-20
- **CRITICITÉ** : SECONDARY
- **QUESTION** : Quels volumes de données, durées et contraintes mémoire sont
  attendus en production ?
- **SOURCE** : `AS_IS.md:687-689` ; `main.R:14-15` ;
  `programs/NR.R:340-395,479-603`.
- **ÉTAT** : À POSER À UN HUMAIN
- **INVESTIGATION STATIQUE** : le code fixe des nombres de processus et appelle
  `memory.limit`, mais ne contient aucune mesure de volume, SLA ou capacité
  machine. Les tailles des données externes sont absentes.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels sont les volumes usuels et
  maximaux, la durée cible, la mémoire disponible et le niveau de parallélisme
  validé pour une production mensuelle ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : les contraintes non fonctionnelles ne
  sont pas documentées.
- **IMPACT — TESTS DE CARACTÉRISATION** : impossible de définir les jeux de
  charge et les seuils de performance.
- **IMPACT — ARCHITECTURE TO-BE** : les besoins de calcul et de stockage ne
  peuvent pas être déduits.
- **IMPACT — PLAN DE MIGRATION** : une migration peut être fonctionnellement
  correcte mais inexploitable à volume réel.

### OQ-21 — Usage aval et validation des sorties CNIV/contrôles

- **ID** : OQ-21
- **CRITICITÉ** : IMPORTANT
- **QUESTION** : Quels contrôles et fichiers CNIV sont officiellement validés
  et consommés en aval ?
- **SOURCE** : `AS_IS.md:658-659,687-689` ; `programs/Controles_imput_PC_yb.R:149-618` ;
  `programs/launch_cniv.R:36-81`.
- **ÉTAT** : PARTIELLEMENT RÉSOLU
- **INVESTIGATION STATIQUE** : les producteurs et plusieurs lectures sont
  visibles. Les consommateurs humains ou systèmes externes, ainsi que les
  critères de validation des XLSX et contrôles, ne sont pas dans le dépôt.
- **RÉPONSE OU QUESTION HUMAINE EXACTE** : « Quels contrôles et fichiers CNIV
  constituent la validation officielle de la production, et quels systèmes ou
  utilisateurs les consomment ? »
- **IMPACT — RÉFÉRENTIEL FONCTIONNEL** : la définition d'une production
  réussie reste incomplète.
- **IMPACT — TESTS DE CARACTÉRISATION** : les tests ne savent pas quels
  contrôles et classeurs doivent être comparés.
- **IMPACT — ARCHITECTURE TO-BE** : les interfaces aval ne sont pas définies.
- **IMPACT — PLAN DE MIGRATION** : un export apparemment secondaire peut être
  indispensable à l'acceptation métier.

## 4. Éléments résolus statiquement sans question humaine supplémentaire

Les points suivants des rapports sont fermés au niveau du dépôt, même si leur
impact opérationnel peut nécessiter une validation ultérieure :

| Sujet | Réponse statique | Référence |
|---|---|---|
| Fonction S4 appelée par `launch_cniv` | `import_confederation_table` et `data_treatment` sont appelées | `programs/launch_cniv.R:9-22` |
| Fonction S4 appelée par le chemin historique NR | `import_historical_simulation`, `import_sample`, `import_gazelec` sont appelées dans `NR.R` | `programs/NR.R:1202-1218,1272-1274` |
| Préparations Refactoring | `import_ca3`, `import_endogenous`, `import_ER`, `import_detail` sont appelées par `prep pipeline.R` | `Refactoring/prep pipeline.R:5-87` |
| Invalidation codée | aucune invalidation par date, hash, paramètre ou mtime observée | `main.R:20-26,88-94`, `NR.R:956-974` |
| Atteignabilité depuis `main.R` | les scripts commentés/non sourcés ne sont pas atteignables dans le chemin principal statique | `main.R:144-169` |
| Ventilation directe 29 | aucun appel direct à `launch_all_distributions` avec `expedition_29` | `launch_expedition.R:50-55` |
| Cas limites des ratios | aucun fallback explicite dans `distribution()` | `NR.R:1029-1075` |
| Versionnement local | aucun manifeste de versions détecté | arborescence du dépôt |

## 5. Limites résiduelles

Les points suivants ne peuvent pas être résolus par une lecture supplémentaire
des mêmes fichiers :

- usage réel hors dépôt ;
- décisions métier non exprimées dans les scripts ;
- producteurs et validateurs externes des inputs ;
- disponibilité et statut des accès réseau ou PostgreSQL ;
- historique des versions de runtime et des données ;
- attentes humaines sur les cas limites de ventilation ;
- contrats aval des outputs.

Une réponse humaine est nécessaire avant de figer le référentiel fonctionnel,
les tests de caractérisation ou tout plan de migration sur ces sujets.

## Conclusion

La structure et plusieurs comportements du code sont désormais résolus
statiquement. Les inconnues bloquantes restantes concernent principalement
l'exploitation réelle et l'intention métier de la ventilation expédition,
notamment pour le régime 29. Aucune proposition To-be n'est incluse.
