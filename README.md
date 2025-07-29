# Imputations

---

## 🚀 Lancement Imputations mensuelles des non-répondants

Consulter le fichier wiki `Imputations production mensuelle pas à pas` sous DGDDI>DSECE>Methodo>Imputations>Wiki

Il détaille toutes les étapes : récupération et enregistrement des données en input, mise à jour de la base historique,  exécution du script `main.R`, et sauvegarde des résultats.

---


## 📌 Prérequis

- Accès aux répertoires réseau (Z:/…)
- Accès à la boîte fonctionnelle `METHODE-STAT@douane.finances.gouv.fr`
- Mail l'Insee avec lien pour télécharger les fichiers parquet CA3
- Mot de passe pour dézipper les fichiers parquet CA3
- Connexion VPN via CiscoAnyConnect (certificat ROSSIGNOL)

---

## 🧩 Structure du code

- `main.R` : script principal découpé en deux parties (paramètres, simulation et contrôles)
- `config.R` : paramètres de la production (mois de référence, chemins, fichiers à utiliser)
- `input/` : dossier contenant les jeux de données intrants 
- `output_PC/` : dossier des output crées par le script 


---

## 📤 Export des résultats

Les fichiers de sortie doivent être copiés à deux emplacements :

- Réseau :  
  `Z:/DG_STAT_prive/1_ETUDES et METHODES/@commun/EMEBI/traitement non-réponse/production_YYYYMM/`

- Local (Kayzer) :  
  `Documents/dsece-imputation-nr/production_YYYYMM/`

---

## 🙋 Contact

Projet maintenu par l’équipe **Methodo**  
Boîte fonctionnelle : `METHODE-STAT@douane.finances.gouv.fr`
