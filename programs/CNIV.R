library(dplyr)
library(lubridate)
library(data.table)
library(xlsx)


setClassUnion("tbl_null", c("tbl", "NULL"))
setClassUnion('character_null', c('character', 'NULL'))
setClassUnion('date_null', c('Date', 'NULL'))

CNIV <- setClass(
  "CNIV", 
  slots = c(data = "tbl_null")
)

setGeneric(name = "response_median_predict", 
           def = function(object, prediction_period, NR_list, 
                          product_var = "ngp", product_list = "all", f = "all"){
             standardGeneric("response_median_predict")
           })
setMethod(f = "response_median_predict", 
          signature = "CNIV", 
          definition = function(object, prediction_period, NR_list, 
                                product_var = "ngp", product_list = "all", f = "all"){
            if (!is.character(product_list)){
              stop("'product' must be 'all' or a list of products NGP9/NC8.")
            }else{
              if (product_list != "all"){
                filtered_data <- filter_(object@data, 
                                         interp(~var %in% product_list, var = prdocut_var)) %>%
                  group_by_(.dots = c('flow', 'siren', 'period', product_var)) %>%
                  summarise(vart = sum(vart), usup = sum(usup))
              }else{
                filtered_data <- object@data %>%
                  group_by_(.dots = c('flow', 'siren', 'period', product_var)) %>%
                  summarise(vart = sum(vart), usup = sum(usup))
              }
            }
            
            if (!is.character(f)){
              stop("'f' must be a string : 'I' (for importation), 'E' (for exportation) or 'all' (for both).")
            }else{
              if (f == 'all'){f <- c('I', 'E')}
            }
            estimation <- data.frame()
            for (date in prediction_period){
              response <- subset(filtered_data, 
                                 subset = ((flow %in% f) & 
                                             (period == as_date(date))))
              prediction <- subset(filtered_data, 
                                   subset = ((flow %in% f) & 
                                               ((year(period) == year(as_date(date)) - 1) |
                                                ((year(period) == year(as_date(date))) &
                                                   (period < as_date(date)))))) %>%
                group_by_(.dots = c(product_var, "siren", "flow")) %>%
                summarise(period = as_date(date)) %>%
                full_join(
                  response %>%
                    group_by_(.dots = c(product_var, "period", "flow")) %>%
                    summarise(
                      # vart_by_response = sum(vart) / n_distinct(siren), 
                      vart_by_response = median(vart),
                      usup_vart_ratio = sum(usup) / sum(vart)
                    ), 
                  by = c(product_var, 'period', 'flow')
                ) %>%
                semi_join(NR_list, by = c('siren', 'flow', 'period')) %>%
                # subset(subset = (siren %in% NR_list[(NR_list$flow == flow) & 
                #                                       (NR_list$period == as_date(date)),]$siren)) %>%
                group_by_(.dots = c(product_var, "period", "flow")) %>%
                summarise(vart_NR_prediction = sum(vart_by_response, na.rm = T), 
                          usup_NR_prediction = vart_NR_prediction*unique(usup_vart_ratio), 
                          nb_NR = n_distinct(siren, na.rm = T))
              estimation <- rbind(estimation, prediction)
            }
            return(estimation)
          })


xlsx.addTitle<-function(sheet, rowIndex, title, titleStyle){
  rows <-createRow(sheet,rowIndex=rowIndex)
  sheetTitle <-createCell(rows, colIndex=1)
  setCellValue(sheetTitle[[1,1]], title)
  setCellStyle(sheetTitle[[1,1]], titleStyle)
}


compute_coverage <- function(response_data,
                             estimation,
                             NR_list,
                             output_dates,
                             f,
                             filename) {
  workbook <- createWorkbook()
  v <- names(estimation)[1]
  for (date in output_dates) {
    # for (date in date_publication[date_publication != date_ref]){
    sheet_name  <- sprintf("%s %s",
                           toupper(v),
                           format(as_date(date),
                                  "%Y-%m-%d"))
    sheet  <- createSheet(wb = workbook, sheetName = sheet_name)
    output_obs <- response_data %>%
      subset(subset = ((period == as_date(date)) &
                         (flow == f))) %>%
      group_by_(.dots = c('type_enquete', v)) %>%
      summarise(
        `Val.(euros)` = sum(vart),
        `Vol.(litre)` = sum(usup),
        `*R` = n_distinct(siren)
      ) %>%
      pivot_wider(
        names_from = type_enquete,
        values_from = c(`Val.(euros)`, `Vol.(litre)`, `*R`),
        names_glue = "{.value} - {type_enquete}",
        values_fill = 0
      ) %>%
      rowwise() %>%
      mutate(
        `Vol.(litre) - EMEBI + DAU` = sum(`Vol.(litre) - EMEBI`, `Vol.(litre) - DAU`, na.rm = T),
        `Val.(euros) - EMEBI + DAU` = sum(`Val.(euros) - EMEBI`, `Val.(euros) - DAU`, na.rm = T),
        `*R - EMEBI + DAU` = sum(`*R - EMEBI`, `*R - DAU`, na.rm = T)
      ) %>%
      select(
        as.name(v),
        `Vol.(litre) - DAU`,
        `Val.(euros) - DAU`,
        `*R - DAU`,
        `Vol.(litre) - EMEBI`,
        `Val.(euros) - EMEBI`,
        `*R - EMEBI`,
        `Vol.(litre) - EMEBI + DAU`,
        `Val.(euros) - EMEBI + DAU`,
        `*R - EMEBI + DAU`
      )
    
    output_imput <- subset(estimation,
                           subset = ((period == as_date(date)) &
                                       (flow == f))) %>%
      data.table::setnames(
        old = c('vart_NR_prediction', 'usup_NR_prediction', 'nb_NR'),
        new = c('Val.(euros)', 'Vol.(litre)', '**NR')
      ) %>%
      select(as.name(v), `Vol.(litre)`, `Val.(euros)`, `**NR`)
    
    output_TC <- response_data %>%
      subset(subset = ((period == (
        as_date(date) - years(1)
      )) &
        (flow == f))) %>%
      group_by_(.dots = c('type_enquete', v)) %>%
      summarise(vart = sum(vart), usup = sum(usup)) %>%
      pivot_wider(
        names_from = type_enquete,
        values_from = c(vart, usup),
        names_sep = "_",
        values_fill = 0
      ) %>%
      rowwise() %>%
      mutate(
        vart_EMEBI_DAU = sum(vart_EMEBI, vart_DAU, na.rm = T),
        usup_EMEBI_DAU = sum(usup_EMEBI, usup_DAU, na.rm = T)
      )
    response <- response_data %>%
      subset(subset = ((period == (
        as_date(date) - years(1)
      )) &
        (flow == f))) %>%
      anti_join(NR_list[(NR_list$period == as_date(date))
                        & (NR_list$flow == f), ],
                by = c('siren', 'period' = 'last_period', 'imex')) %>%
      group_by_(.dots = c('type_enquete', v)) %>%
      summarise(vart = sum(vart), usup = sum(usup)) %>%
      pivot_wider(
        names_from = type_enquete,
        values_from = c(vart, usup),
        names_sep = "_",
        values_fill = 0
      ) %>%
      rowwise() %>%
      mutate(
        vart_EMEBI_DAU = sum(vart_EMEBI, vart_DAU, na.rm = T),
        usup_EMEBI_DAU = sum(usup_EMEBI, usup_DAU, na.rm = T)
      )
    
    output_TC <- output_TC %>%
      full_join(response,
                by = v,
                suffix = c('_total', '_rep')) %>% rowwise() %>%
      mutate(
        `Vol.(%) - EMEBI` = usup_EMEBI_rep / usup_EMEBI_total * 100,
        `Val.(%) - EMEBI` = vart_EMEBI_rep / vart_EMEBI_total * 100,
        `Vol.(%) - EMEBI + DAU` = usup_EMEBI_DAU_rep / usup_EMEBI_DAU_total * 100,
        `Val.(%) - EMEBI + DAU` = vart_EMEBI_DAU_rep / vart_EMEBI_DAU_total * 100
      ) %>%
      full_join(output_obs[, c(v, "*R - EMEBI", "*R - EMEBI + DAU")], by = v) %>%
      full_join(output_imput[, c(v, "**NR")], by = v) %>%
      rowwise() %>%
      mutate(
        `*R(%) - EMEBI` = `*R - EMEBI` / sum(`*R - EMEBI`, `**NR`, na.rm = T) * 100,
        `*R(%) - EMEBI + DAU` = `*R - EMEBI + DAU` /
          sum(`*R - EMEBI + DAU`, `**NR`, na.rm = T) * 100
      ) %>%
      select(
        as.name(v),
        `Vol.(%) - EMEBI`,
        `Val.(%) - EMEBI`,
        `*R(%) - EMEBI`,
        `Vol.(%) - EMEBI + DAU`,
        `Val.(%) - EMEBI + DAU`,
        `*R(%) - EMEBI + DAU`
      )
    xlsx::addDataFrame(
      as.data.frame(left_join(
        output_obs,
        full_join(output_imput,
                  output_TC,
                  by = v),
        by = v
      )) %>%
        select(
          as.name(v),
          `Vol.(litre) - DAU`,
          `Val.(euros) - DAU`,
          `*R - DAU`,
          `Vol.(litre) - EMEBI`,
          `Val.(euros) - EMEBI`,
          `*R - EMEBI`,
          `Vol.(litre) - EMEBI + DAU`,
          `Val.(euros) - EMEBI + DAU`,
          `*R - EMEBI + DAU`,
          `Vol.(litre)`,
          `Val.(euros)`,
          `**NR`,
          `Vol.(%) - EMEBI`,
          `Val.(%) - EMEBI`,
          `*R(%) - EMEBI`,
          `Vol.(%) - EMEBI + DAU`,
          `Val.(%) - EMEBI + DAU`,
          `*R(%) - EMEBI + DAU`
        ),
      # %>%
      sheet,
      row.names = F
    )
  }
  xlsx::saveWorkbook(wb = workbook, file = filename)
}

cut_by_interprofession <- function(data_table, confederation_table, 
                                   filename){
  output_file <- createWorkbook(type = "xlsx")
  for (confederation in unique(confederation_table$code_orga)){
    sheet <- createSheet(output_file, sheetName = confederation)
    result <- bind_rows(
      semi_join(
        data_table, 
        confederation_table[is.na(confederation_table$ngp) & 
                              (confederation_table$code_orga == confederation),
                            c('nc8', 'code_orga')],
        by = 'nc8'
      ), 
      semi_join(
        data_table, 
        confederation_table[!is.na(confederation_table$ngp) & 
                              (confederation_table$code_orga == confederation),
                            c('ngp', 'code_orga')],
        by = 'ngp'
      )
    ) %>%
      as.data.frame()
    addDataFrame(x = result, sheet = sheet, row.names = F)
  }
  saveWorkbook(output_file, 
               file = filename)
}


build_ending_file <- function(data_file, wb, confederation_table, confederation, 
                              filename_format, f){
  flow_dict <- data.frame(flow = c('I', 'E'),
                          flow_lib_EMEBI = c("Introductions", "Expeditions"),
                          flow_lib_EMEBI = c("INTRODUCTIONS", "EXPEDITIONS"),
                          flow_lib_dau = c("Importations", "Exportations"),
                          flow_lib_DAU = c("IMPORTATIONS", "EXPORTATIONS"))
  # wb<-loadWorkbook("../data/EXPORTATIONS_DEB-DAU_CNIV.xlsx")
  sheet_names <- names(getSheets(wb))
  sheet_names <- sheet_names[sheet_names != "Lisez-moi"]
  map(.x = sheet_names, ~removeSheet(wb, .x))
  
  TITLE_STYLE <- CellStyle(wb)+ Font(wb,  heightInPoints=16,
                                     color="blue", isBold=TRUE, underline=1)
  SUB_TITLE_STYLE <- CellStyle(wb) +
    Font(wb,  heightInPoints=14,
         isItalic=TRUE, isBold=FALSE)
  TABLE_ROWNAMES_STYLE <- CellStyle(wb) +
    Font(wb, isBold=TRUE)
  TABLE_COLNAMES_STYLE <- CellStyle(wb) +
    Font(wb, isBold=TRUE, color = '#00008B') +
    Fill(foregroundColor = '#87CEFA', backgroundColor = '#87CEFA') +
    Alignment(wrapText=TRUE, horizontal="ALIGN_CENTER") +
    Border(color="black", position=c("TOP", "BOTTOM"),
           pen=c("BORDER_THICK", "BORDER_THICK"))
  TABLE_DATA_STYLE <- CellStyle(wb) + DataFormat(("###0,00"))

  sheets <- openxlsx::getSheetNames(data_file)
  for (sheetname in sheets){
    date <- as_date(strsplit(sheetname, split = " ")[[1]][2])
    data_table <- openxlsx::readWorkbook(xlsxFile = data_file, sheet = sheetname, 
                                         sep.names = " ", na.strings = "")
    if (confederation != "CNIV"){
      data_table <- data_table %>%
        rowwise() %>%
        mutate(nc8 = substr(ngp, 1, 8)) %>%
        ungroup()
      data_table <- bind_rows(
        semi_join(data_table, 
                  confederation_table[is.na(confederation_table$ngp) &
                                        (confederation_table$code_orga == confederation),
                                      c('nc8', 'code_orga')], 
                  by = 'nc8'),
        semi_join(data_table, 
                  confederation_table[!is.na(confederation_table$ngp) &
                                        (confederation_table$code_orga == confederation),
                                      c('ngp', 'code_orga')], 
                  by = 'ngp')
      ) %>% 
        select(-nc8) %>%
        as.data.frame()
    }
    sheet <- createSheet(wb, sheetName = sheetname)
    xlsx.addTitle(sheet, rowIndex=1,
                  title=sprintf("%s [%s]",
                                flow_dict[flow_dict$flow == f,]$flow_lib_dau,
                                format(as_date(date), "%Y-%m")),
                  titleStyle = TITLE_STYLE)
    xlsx.addTitle(sheet, rowIndex=2,
                  title="*R (nombre de Repondant) - **NR (nombre de Non Repondant)",
                  titleStyle = SUB_TITLE_STYLE)
    rows <- createRow(sheet, 3:4)
    cells_obs <- createCell(rows, colIndex = 2:10)
    cells_imput <- createCell(rows, colIndex = 11:13)
    cells_TC <- createCell(rows, colIndex = 14:19)
    setCellValue(cells_imput[[1,1]], sprintf("EMEBI des NR de %s", format(as_date(date), "%Y-%m")))
    setCellStyle(cells_imput[[1,1]], cellStyle = TABLE_COLNAMES_STYLE)
    setCellStyle(cells_imput[[1,2]], cellStyle = TABLE_COLNAMES_STYLE)
    setCellStyle(cells_imput[[1,3]], cellStyle = TABLE_COLNAMES_STYLE)
    addMergedRegion(sheet, startRow = 3, endRow = 4, startColumn = 11, endColumn = 13)

    setCellValue(cells_obs[[1,1]], sprintf("%s %s : Montants observes sur le champ de ...",
                                           flow_dict[flow_dict$flow == f,]$flow_lib_EMEBI,
                                           format(as_date(date), "%Y-%m")))
    setCellStyle(cells_obs[[1,1]], cellStyle = CellStyle(wb) + Alignment(wrapText = T, horizontal = "ALIGN_CENTER"))
    addMergedRegion(sheet, startRow = 3, endRow = 3, startColumn = 2, endColumn = 10)
    
    
    setCellValue(cells_TC[[1,1]], sprintf("Taux de couverture sur le champ ..."))
    setCellStyle(cells_TC[[1,1]], cellStyle = CellStyle(wb) + Alignment(wrapText = T, horizontal = "ALIGN_CENTER"))
    addMergedRegion(sheet, startRow = 3, endRow = 3, startColumn = 14, endColumn = 19)
    
    addMergedRegion(sheet, startRow = 4, endRow = 4, startColumn = 2, endColumn = 4)
    setCellValue(cells_obs[[2,1]], "DAU")
    setCellStyle(cells_obs[[1,1]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,2]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,3]], TABLE_COLNAMES_STYLE)
    
    setCellValue(cells_obs[[2,4]], "EMEBI")
    setCellStyle(cells_obs[[1,4]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,5]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,6]], TABLE_COLNAMES_STYLE)
    addMergedRegion(sheet, startRow = 4, endRow = 4, startColumn = 5, endColumn = 7)
    setCellValue(cells_obs[[2,7]], "EMEBI + DAU")
    setCellStyle(cells_obs[[1,7]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,8]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_obs[[1,9]], TABLE_COLNAMES_STYLE)
    addMergedRegion(sheet, startRow = 4, endRow = 4, startColumn = 8, endColumn = 10)
    
    setCellValue(cells_TC[[2,1]], "EMEBI")
    setCellStyle(cells_TC[[1,1]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_TC[[1,2]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_TC[[1,3]], TABLE_COLNAMES_STYLE)
    addMergedRegion(sheet, startRow = 4, endRow = 4, startColumn = 14, endColumn = 16)
    setCellValue(cells_TC[[2,4]], "EMEBI + DAU")
    setCellStyle(cells_TC[[1,4]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_TC[[1,5]], TABLE_COLNAMES_STYLE)
    setCellStyle(cells_TC[[1,6]], TABLE_COLNAMES_STYLE)
    addMergedRegion(sheet, startRow = 4, endRow = 4, startColumn = 17, endColumn = 19)
    # print(names(data_table))

    addDataFrame(
      data_table %>%
        data.table::setnames(old = c("Vol.(litre) - DAU", "Val.(euros) - DAU", "*R - DAU",
                                     "Vol.(litre) - EMEBI", "Val.(euros) - EMEBI", "*R - EMEBI",
                                     "Vol.(litre) - EMEBI + DAU", "Val.(euros) - EMEBI + DAU", "*R - EMEBI + DAU",
                                     "Vol.(%) - EMEBI", "Val.(%) - EMEBI", "*R(%) - EMEBI",
                                     "Vol.(%) - EMEBI + DAU", "Val.(%) - EMEBI + DAU", "*R(%) - EMEBI + DAU"),
                             new = c("Vol.(litre)", "Val.(euros)", "*R",
                                     "Vol.(litre)", "Val.(euros)", "*R",
                                     "Vol.(litre)", "Val.(euros)", "*R",
                                     "Vol.(%)", "Val.(%)", "*R(%)",
                                     "Vol.(%)", "Val.(%)", "*R(%)")),
      sheet, startRow = 5, startColumn=1,
      colnamesStyle = TABLE_COLNAMES_STYLE,
      colStyle = list(`1` = CellStyle(wb),
                      `2` = TABLE_DATA_STYLE,
                      `3` = TABLE_DATA_STYLE,
                      `4` = CellStyle(wb),
                      `5` = TABLE_DATA_STYLE,
                      `6` = TABLE_DATA_STYLE,
                      `7` = CellStyle(wb),
                      `8` = TABLE_DATA_STYLE,
                      `9` = TABLE_DATA_STYLE,
                      `10` = CellStyle(wb),
                      `11` = TABLE_DATA_STYLE,
                      `12` = TABLE_DATA_STYLE,
                      `13` = CellStyle(wb),
                      `14` = TABLE_DATA_STYLE,
                      `15` = TABLE_DATA_STYLE,
                      `16` = TABLE_DATA_STYLE,
                      `17` = TABLE_DATA_STYLE,
                      `18` = TABLE_DATA_STYLE,
                      `19` = TABLE_DATA_STYLE),
      row.names = F)
    setColumnWidth(sheet, colIndex=1:ncol(data_table), colWidth=11)
    
    # cells_lowTC <- createCell(getRows(sheet, 1:2), colIndex = c(15,18))
    # setCellValue(cells_lowTC[[1,1]], sprintf("Nb NGP dont Val.(%s) - DEB < 95 %s", "%", "%"))
    # setCellStyle(cells_lowTC[[1,1]], cellStyle = CellStyle(wb) +
    #                Fill(backgroundColor = "yellow", foregroundColor = "yellow") +
    #                Alignment(wrapText = T))
    # setCellValue(cells_lowTC[[2,1]], sum(!(data_table$`Val.(%) - DEB` >= 95),na.rm = T))
    # setCellStyle(cells_lowTC[[2,1]], cellStyle = CellStyle(wb)
    #              + Fill(backgroundColor = "yellow", foregroundColor = "yellow"))
    # setCellValue(cells_lowTC[[1,2]], sprintf("Nb NGP dont Val.(%s) - DEB + DAU < 95 %s", "%", "%"))
    # setCellStyle(cells_lowTC[[1,2]], cellStyle = CellStyle(wb)
    #              + Fill(backgroundColor = "yellow", foregroundColor = "yellow") +
    #                Alignment(wrapText = T))
    # setCellValue(cells_lowTC[[2,2]], sum(!(data_table$`Val.(%) - DEB + DAU` >= 95),na.rm = T))
    # setCellStyle(cells_lowTC[[2,2]], cellStyle = CellStyle(wb)
    #              + Fill(backgroundColor = "yellow", foregroundColor = "yellow"))
    
  }
  saveWorkbook(wb, sprintf(filename_format, confederation))
}
