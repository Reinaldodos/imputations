testthat::test_that("compare_data detects semantic equality and differences", {
  source(testthat::test_path("../../golden_master.R"))
  reference <- data.frame(
    id = c("a", "b"),
    method = c("M-12", "mean"),
    prediction = c(NA_real_, 0),
    stringsAsFactors = FALSE
  )
  current <- reference
  testthat::expect_true(compare_data(reference, current, keys = "id")$ok)
  current$prediction[[2]] <- 1
  testthat::expect_false(compare_data(reference, current, keys = "id")$ok)
  testthat::expect_true(any(grepl("values differ: prediction",
                                  compare_data(reference, current)$differences)))
})

testthat::test_that("CSV and RDS comparators preserve NA and structure", {
  source(testthat::test_path("../../golden_master.R"))
  reference <- data.frame(id = c("a", "b"), value = c(NA_real_, 0),
                          stringsAsFactors = FALSE)
  ref_csv <- tempfile(fileext = ".csv")
  cur_csv <- tempfile(fileext = ".csv")
  utils::write.csv2(reference, ref_csv, row.names = FALSE, na = "")
  utils::write.csv2(reference, cur_csv, row.names = FALSE, na = "")
  testthat::expect_true(compare_csv(ref_csv, cur_csv, keys = "id")$ok)

  ref_rds <- tempfile(fileext = ".rds")
  cur_rds <- tempfile(fileext = ".rds")
  saveRDS(reference, ref_rds)
  saveRDS(reference, cur_rds)
  testthat::expect_true(compare_rds(ref_rds, cur_rds)$ok)
  saveRDS(transform(reference, value = c(1, 0)), cur_rds)
  testthat::expect_false(compare_rds(ref_rds, cur_rds)$ok)
})

testthat::test_that("artifact tree compares listed CSV, RDS and generic files", {
  source(testthat::test_path("../../golden_master.R"))
  reference_dir <- tempfile("gm-reference-")
  current_dir <- tempfile("gm-current-")
  dir.create(file.path(reference_dir, "nested"), recursive = TRUE)
  dir.create(file.path(current_dir, "nested"), recursive = TRUE)
  value <- data.frame(id = "a", value = 0, stringsAsFactors = FALSE)
  utils::write.csv2(value, file.path(reference_dir, "value.csv"), row.names = FALSE)
  utils::write.csv2(value, file.path(current_dir, "value.csv"), row.names = FALSE)
  saveRDS(value, file.path(reference_dir, "nested", "value.rds"))
  saveRDS(value, file.path(current_dir, "nested", "value.rds"))
  writeLines("technical fixture", file.path(reference_dir, "note.txt"))
  writeLines("technical fixture", file.path(current_dir, "note.txt"))
  manifest <- data.frame(
    path = c("value.csv", "nested/value.rds", "note.txt"),
    type = c("csv", "rds", "file"),
    stringsAsFactors = FALSE
  )
  testthat::expect_true(compare_artifact_tree(reference_dir, current_dir, manifest)$ok)
  writeLines("changed", file.path(current_dir, "note.txt"))
  testthat::expect_false(compare_artifact_tree(reference_dir, current_dir, manifest)$ok)
})

testthat::test_that("capture_reference records a successful isolated run", {
  source(testthat::test_path("../../golden_master.R"))
  workdir <- tempfile("gm-workdir-")
  snapshot_dir <- tempfile("gm-snapshot-")
  dir.create(workdir)
  run_legacy <- function() {
    writeLines("synthetic legacy log", file.path(workdir, "result.txt"))
    list(status = 0L, stdout = "stdout", stderr = character())
  }
  result <- capture_reference(
    workdir = workdir,
    snapshot_dir = snapshot_dir,
    artifact_paths = "result.txt",
    run_legacy = run_legacy,
    metadata = list(fixture = "synthetic technical test")
  )
  testthat::expect_equal(result$status, 0L)
  testthat::expect_true(file.exists(file.path(snapshot_dir, "run.rds")))
  testthat::expect_true(file.exists(file.path(snapshot_dir, "stdout.log")))
  testthat::expect_true(file.exists(file.path(snapshot_dir, "artifacts", "result.txt")))
  testthat::expect_true(is.na(gm_hash_if_deterministic("missing", "xlsx", TRUE)))
})

testthat::test_that("capture_reference rejects unsafe artifact paths", {
  source(testthat::test_path("../../golden_master.R"))
  workdir <- tempfile("gm-workdir-")
  dir.create(workdir)
  testthat::expect_error(
    capture_reference(workdir, tempfile("gm-snapshot-"), "../outside.txt",
                      function() 0L),
    "relative"
  )
})
