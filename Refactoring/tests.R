
test_last_CA3 <- function(base_CA3, date_ref) {
  testthat::test_that(desc = "La base CA3 est-elle à date?",
                      code = {
                        testthat::expect_equal(lubridate::ym(get_last_ca3(base_CA3 = base_CA3)), date_ref)
                      })
}


test_MSD_fichiers_presents <- function(msd_file) {
  testthat::test_that(desc = "Les fichiers MSD sont-ils tous présents?",
                      code = {
                        file.path(msd_file$directory, msd_file$files) %>%
                          file.exists() %>% all() %>%
                          testthat::expect_true()
                      })
}
