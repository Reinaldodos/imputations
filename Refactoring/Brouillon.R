
source(file = "Refactoring/Fonctions/import_detail.R",
       encoding = "UTF-8")

test <-
  import_detail(
    source_file = intro_ventil_file,
    delete_data = delete,
    condition = condition = "payp %notin% c('XU', 'GB')"
  )

