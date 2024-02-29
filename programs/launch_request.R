library(RPostgreSQL)
library(doParallel)

user = "ngle_pp"
pwd = "TFscCizOdV1jO31OBjCu"

unregister_dopar <- function() {
  env <- foreach:::.foreachGlobals
  rm(list=ls(name=env), pos=env)
}

WriteCommand <- function(from, to, type){
  period <- seq.Date(from = from, to = to, by = 'month') %>%
    as_tibble() %>%
    mutate(adep = format(value, "%Y"), 
           mdep = format(value, "%m")) %>%
    group_by(adep) %>%
    mutate(month_command = sprintf("mdep in (%s)", paste("'", mdep, "'", collapse = ", ", sep = ""))) %>%
    ungroup() %>%
    group_by(month_command) %>%
    summarise(command = sprintf("((adep in (%s)) and (%s))", 
                                paste("'", unique(adep), "'", collapse = ", ", sep = ""), 
                                month_command)) %>%
    ungroup() %>%
    select(command) %>%
    unique() %>%
    flatten_chr() %>%
    paste("(", ., ")", collapse = " or ", sep = "")
  
  dict <- data.frame(
    type = c("intro_imput", "intro_ventil", "exped_imput", "exped_ventil", "ER_exped", "vin-spiritueux"), 
    var = c("sire, adep, mdep", 
            "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
            "sire, adep, mdep, regdem", 
            "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
            "sire, adep, mdep, regdem", 
            "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end flux"),
    var_group_by = c("sire, adep, mdep", 
                     "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                     "sire, adep, mdep, regdem", 
                     "sire, adep, mdep, a129, nc8, payp, pyod, dept, regdem, temo, natr, conf", 
                     "sire, adep, mdep, regdem", 
                     "sire, adep, mdep, ngp, nc8, imex, case when imex in ('1', '3') then 'I' else 'E' end"),
    agg_var = c("vart", "vart", "vart", "vart", "vart, vfte", 
                "vart, usup") 
  ) %>%
    mutate(condition = case_when(
      (grepl(pattern = "intro", x = type)) ~ "(imex = '3') and (oblig = '1') and (vaco in ('1', '3'))", 
      (grepl(pattern = "imput", x = type) | grepl(pattern = "ventil", x = type)) ~ "(imex = '4') and (oblig = '1') and (vaco in ('1', '3'))", 
      (grepl(pattern = "ER", x = type)) ~ "(oblig = '4') and (regdem = '21')", 
      TRUE ~ "((nc8 like '2204%') or (nc8 like '2208%')) and (vaco in ('1','3'))"
    ))
  var <- dict[dict$type == type,]$var
  var_group_by <- dict[dict$type == type,]$var_group_by
  agg_var <- dict[dict$type == type,]$agg_var %>% str_split(", ") %>% flatten_chr()
  condition <- dict[dict$type == type,]$condition
  command <- sprintf(
    "select %s, %s from sc_astrineo.florea where ((%s) and %s) group by %s", 
    var, 
    paste(sprintf("sum(%s) %s", agg_var, agg_var), collapse = ", "), 
    period, 
    condition, 
    var_group_by
  )
  return(command)
}

request_data <-  bind_rows(
  intro_imput_file %>%
    subset(subset = !historical, select = -c(historical, astrineo_input, skiprows, encoding, dec)), 
  exped_imput_file %>%
    subset(subset = !historical, select = -c(historical, astrineo_input, skiprows, encoding, dec)), 
  intro_ventil_file %>% select(-astrineo_input, skiprows, encoding, dec), 
  exped_ventil_file %>% select(-astrineo_input, skiprows, encoding, dec),
  ER_file %>% select(-c(skiprows, encoding, dec)), 
  cniv_file %>% subset(subset = (type == "input"), select = c(directory, files, start, end))
) %>% 
  rowwise() %>%
  mutate(
  command = WriteCommand(start, end, (str_split(files, "_20") %>% flatten_chr())[1])
) %>%
  ungroup()

cl <- makeCluster(5, outfile = 'output.txt')
registerDoParallel(cl)
start_time <- Sys.time()
foreach(irow = 1:nrow(request_data), 
        .packages = c('dplyr', 'RPostgreSQL')) %dopar% 
  {
    connexion <- dbConnect(PostgreSQL(), dbname = "db_etudes", port = 5440,
                           host="dxproetudba01.adm.dnsce.douane",
                           user = user, password = pwd)
    file_name <- file.path(request_data[irow,]$directory, 
                           request_data[irow,]$files)
    data <- dbGetQuery(conn = connexion, statement = sql(request_data[irow,]$command))
    if (grepl(pattern = "vin-spiritueux", x = request_data[irow,]$files)){
      data <- data %>% 
        group_by(sire, adep, mdep, ngp, nc8, imex) %>%
        mutate(vart_e = sum(vart[flux == "E"]), 
               vart_i = sum(vart[flux == "I"]), 
               usup_e = sum(usup[flux == "E"]), 
               usup_i = sum(usup[flux == "I"])) %>%
        ungroup() %>%
        select(-vart, -usup)
    }
    dbDisconnect(connexion)
    write.csv2(data,
               file = file_name,
               row.names = F, 
               quote = F, 
               na = "")
  }
stopCluster(cl)
print(Sys.time() - start_time)
unregister_dopar()
