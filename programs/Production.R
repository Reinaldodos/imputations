library(dplyr)
library(data.table)
library(lubridate)


setClassUnion("tbl_null", c("tbl", "NULL"))
Production <- setClass("Production",
                       
                       slots = c(introduction = "tbl_null",
                                 expedition = "tbl_null",
                                 pass_table  ="tbl_null"))

setGeneric(name = "GetNationalFormat",
           def = function(object, filename, exclu, matmil = T){
             standardGeneric("GetNationalFormat")
           })
setMethod(f ="GetNationalFormat",
          signature = "Production",
          definition = function(object, filename, exclu, matmil = T){
            if (matmil){
              exped <- object@expedition %>%
                subset(subset = (conf == "3"))
              intro <- object@introduction %>%
                subset(subset = (conf == "3"))
            }else{
              exped <- object@expedition %>%
                subset(subset = !(conf == "3"))
              intro <- object@introduction %>%
                subset(subset = !(conf == "3"))
            }
            exped <- (mutate(exped, adep = year(period), mdep = month(period), flux = 'E')
                      %>% group_by(a129, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)))
            intro <- (mutate(intro, adep = year(period), mdep = month(period), flux = 'I')
                      %>% group_by(a129, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)))
            result <- rbind(exped, intro) %>% subset(subset = (!(pyod %in% exclu) & !is.na(pyod) & (pyod != "") & 
                                                                 !(is.na(a129)) & (a129 != "") & 
                                                                 !is.na(adep) & (adep != "") & 
                                                                 !is.na(mdep) & (mdep != "") & 
                                                                 !is.na(vart)))
            write.csv2(result, filename, row.names = FALSE, na = "")
            return(result)
          })

setGeneric(name = "GetEurostatSH2Format", 
           def = function(object, filename, exclu){
             standardGeneric("GetEurostatSH2Format")
           })
setMethod(f = "GetEurostatSH2Format",
          signature = "Production", 
          definition = function(object, filename, exclu){
            result <- rbind(
              mutate(object@expedition, adep = year(period), mdep = month(period), flux = 'E', sh2 = ifelse(conf=="3","99",substr(nc8, 1, 2)),pyod=ifelse(conf=="3","QY",pyod))
              %>% group_by(sh2, pyod, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "pyod"),
              mutate(object@introduction, adep = year(period), mdep = month(period), flux = 'I', sh2 = ifelse(conf=="3","99",substr(nc8, 1, 2)),payp=ifelse(conf=="3","QY",payp))
              %>% group_by(sh2, payp, flux, adep, mdep) %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "payp")
            )%>% subset(subset = (!(`pyod(exped) / payp(intro)` %in% exclu) & !is.na(`pyod(exped) / payp(intro)`) & (`pyod(exped) / payp(intro)` != "") & 
                                    !(is.na(sh2)) & (sh2 != "") & 
                                    !is.na(adep) & (adep != "") & 
                                    !is.na(mdep) & (mdep != "") & 
                                    !is.na(vart)))
            write.csv2(result, filename, row.names = FALSE, na = "")
            return(result)
          })

setGeneric(name = "GetEurostatCTCIFormat",
          def = function(object, filename, exclu){
            standardGeneric("GetEurostatCTCIFormat")
          })
setMethod(f = "GetEurostatCTCIFormat",
          signature = "Production",
          definition = function(object, filename, exclu){
            intro <- (mutate(object@introduction, adep = year(period), mdep = month(period), flux = 'I', adep_last = year(period_last))
                      %>% left_join(object@pass_table[,c("year", "nc8", "ctci")], by = c("adep_last" = "year", "nc8")))
            intro <-(intro
                     %>% mutate(ctci=ifelse(conf=="3","93100",ctci),payp = ifelse(conf=="3","QY",payp))
                     %>% group_by_(.dots = c("ctci", "payp", "flux", "adep", "mdep"))
                     %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "payp"))
            exped <- (mutate(object@expedition, adep = year(period), mdep = month(period), flux = 'E', adep_last = year(period_last))
                      %>% left_join(object@pass_table[,c("year", "nc8", "ctci")], by = c("adep_last" = "year", "nc8")))
            exped <- (exped 
                      %>% mutate(ctci=ifelse(conf=="3","93100",ctci),pyod=ifelse(conf=="3","QY",pyod))
                      %>% group_by_(.dots = c("ctci", "pyod", "flux", "adep", "mdep")) 
                      %>% summarise(vart = sum(dist_prediction, na.rm = TRUE)) %>% rename("pyod(exped) / payp(intro)" = "pyod"))
            result <- rbind(exped, intro) %>% 
              subset(subset = (!(`pyod(exped) / payp(intro)` %in% exclu) & !is.na(`pyod(exped) / payp(intro)`) & (`pyod(exped) / payp(intro)` != "") & 
                                 !(is.na(ctci)) & (ctci != "") & 
                                 !is.na(adep) & (adep != "") & 
                                 !is.na(mdep) & (mdep != "") & 
                                 !is.na(vart)))
            write.csv2(result, filename, row.names = FALSE, na = "")
            return(result)
          })