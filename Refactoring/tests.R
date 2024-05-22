test_MSD_fichiers_presents <- function(msd_file) {
  fichiers_manquant = 
    msd_file %>%
    mutate(TEST = file.path(msd_file$directory, msd_file$files) %>%
             file.exists()) %>%
    filter(!TEST) %>% 
    mutate(fichier = file.path(directory, files)) %>% 
    pull(fichier)
  
  if(length(fichiers_manquant)>0) {
    cat("les fichiers suivants n'existent pas: \n",
        paste(fichiers_manquant, collapse = "\n"), 
        "\n")
    stop()
  }
}
