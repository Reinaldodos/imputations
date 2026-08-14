# Minimal Golden Master harness.
# This file does not source or modify main.R.

gm_result <- function(ok = TRUE, semantic_ok = TRUE, structural_ok = TRUE,
                      binary_ok = NA, differences = character(), details = list()) {
  list(
    ok = isTRUE(ok),
    semantic_ok = isTRUE(semantic_ok),
    structural_ok = isTRUE(structural_ok),
    binary_ok = binary_ok,
    differences = differences,
    details = details
  )
}

gm_fail <- function(message, structural = TRUE) {
  gm_result(
    ok = FALSE,
    semantic_ok = FALSE,
    structural_ok = !structural,
    binary_ok = NA,
    differences = message
  )
}

compare_data <- function(reference, current, keys = NULL, check_types = TRUE,
                         tolerance = 0) {
  differences <- character()
  if (!is.data.frame(reference) || !is.data.frame(current)) {
    same <- isTRUE(all.equal(reference, current, tolerance = tolerance))
    return(gm_result(same, same, same,
                     differences = if (same) character() else "objects differ"))
  }

  if (!identical(names(reference), names(current))) {
    differences <- c(differences, "column names differ")
  }
  if (!identical(nrow(reference), nrow(current))) {
    differences <- c(differences, "row count differs")
  }
  common <- intersect(names(reference), names(current))
  if (check_types) {
    for (name in common) {
      if (!identical(class(reference[[name]]), class(current[[name]]))) {
        differences <- c(differences, sprintf("type differs: %s", name))
      }
    }
  }
  if (!is.null(keys) && all(keys %in% common)) {
    ref_keys <- reference[keys]
    cur_keys <- current[keys]
    if (!isTRUE(all.equal(ref_keys, cur_keys, check.attributes = TRUE,
                          tolerance = tolerance))) {
      differences <- c(differences, "keys or key order differ")
    }
  }
  if (length(common) > 0L && nrow(reference) == nrow(current)) {
    for (name in common) {
      equal <- isTRUE(all.equal(reference[[name]], current[[name]],
                                check.attributes = check_types,
                                tolerance = tolerance))
      if (!equal) differences <- c(differences, sprintf("values differ: %s", name))
    }
  }
  differences <- unique(differences)
  gm_result(length(differences) == 0L,
            semantic_ok = length(differences) == 0L,
            structural_ok = length(differences) == 0L,
            differences = differences,
            details = list(keys = keys, columns = common))
}

compare_csv <- function(reference, current, keys = NULL, sep = ";",
                        dec = ",", encoding = "UTF-8") {
  if (!file.exists(reference) || !file.exists(current)) {
    return(gm_fail("CSV reference or current file is missing"))
  }
  ref <- utils::read.table(reference, header = TRUE, sep = sep, dec = dec,
                           quote = "\"", comment.char = "",
                           fileEncoding = encoding, check.names = FALSE,
                           stringsAsFactors = FALSE, na.strings = "")
  cur <- utils::read.table(current, header = TRUE, sep = sep, dec = dec,
                           quote = "\"", comment.char = "",
                           fileEncoding = encoding, check.names = FALSE,
                           stringsAsFactors = FALSE, na.strings = "")
  result <- compare_data(ref, cur, keys = keys, check_types = FALSE)
  result$details$format <- "CSV semantic/structural comparison"
  result
}

compare_rds <- function(reference, current, check_types = TRUE) {
  if (!file.exists(reference) || !file.exists(current)) {
    return(gm_fail("RDS reference or current file is missing"))
  }
  ref <- readRDS(reference)
  cur <- readRDS(current)
  if (is.data.frame(ref) && is.data.frame(cur)) {
    result <- compare_data(ref, cur, check_types = check_types)
  } else {
    same <- isTRUE(all.equal(ref, cur, check.attributes = check_types,
                             tolerance = 0))
    result <- gm_result(same, same, same,
                        differences = if (same) character() else "RDS values differ")
  }
  result$details$format <- "RDS semantic/structural comparison; no binary hash"
  result
}

compare_arrow <- function(reference, current, keys = NULL) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    return(gm_fail("arrow package is required for compare_arrow()"))
  }
  if (!file.exists(reference) || !file.exists(current)) {
    return(gm_fail("Arrow reference or current path is missing"))
  }
  read_arrow <- function(path) {
    if (dir.exists(path)) arrow::open_dataset(path) |> arrow::collect()
    else arrow::read_feather(path)
  }
  result <- compare_data(read_arrow(reference), read_arrow(current), keys = keys)
  result$details$format <- "Arrow semantic/structural comparison; no binary hash"
  result
}

compare_xlsx <- function(reference, current, keys = NULL) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    return(gm_fail("readxl package is required for compare_xlsx()"))
  }
  if (!file.exists(reference) || !file.exists(current)) {
    return(gm_fail("XLSX reference or current file is missing"))
  }
  ref_sheets <- readxl::excel_sheets(reference)
  cur_sheets <- readxl::excel_sheets(current)
  if (!identical(ref_sheets, cur_sheets)) {
    return(gm_result(FALSE, FALSE, FALSE, NA,
                     differences = "XLSX sheet names/order differ",
                     details = list(reference_sheets = ref_sheets,
                                    current_sheets = cur_sheets)))
  }
  details <- lapply(ref_sheets, function(sheet) {
    compare_data(readxl::read_excel(reference, sheet = sheet),
                 readxl::read_excel(current, sheet = sheet), keys = keys,
                 check_types = FALSE)
  })
  differences <- unlist(lapply(seq_along(details), function(i) {
    if (isTRUE(details[[i]]$ok)) character()
    else sprintf("sheet %s: %s", ref_sheets[[i]], details[[i]]$differences)
  }), use.names = FALSE)
  gm_result(length(differences) == 0L, length(differences) == 0L,
            length(differences) == 0L, NA, unique(differences),
            list(sheets = ref_sheets,
                 note = "XLSX compared structurally/semantically, never by binary hash"))
}

gm_hash_if_deterministic <- function(path, type, deterministic = FALSE) {
  if (!isTRUE(deterministic) || !(type %in% c("csv", "txt", "tsv", "json"))) {
    return(NA_character_)
  }
  unname(as.character(tools::md5sum(path)))
}

compare_artifact_tree <- function(reference_dir, current_dir, manifest) {
  if (!dir.exists(reference_dir) || !dir.exists(current_dir)) {
    return(gm_fail("reference or current artifact directory is missing"))
  }
  required <- c("path", "type")
  if (!all(required %in% names(manifest))) {
    stop("manifest must contain path and type columns", call. = FALSE)
  }
  results <- vector("list", nrow(manifest))
  for (i in seq_len(nrow(manifest))) {
    rel <- manifest$path[[i]]
    type <- tolower(manifest$type[[i]])
    ref <- file.path(reference_dir, rel)
    cur <- file.path(current_dir, rel)
    keys <- if ("keys" %in% names(manifest)) manifest$keys[[i]] else NULL
    if (is.character(keys) && length(keys) == 1L && grepl(",", keys, fixed = TRUE)) {
      keys <- trimws(strsplit(keys, ",", fixed = TRUE)[[1]])
    }
    result <- switch(type,
      csv = compare_csv(ref, cur, keys = keys),
      rds = compare_rds(ref, cur),
      arrow = compare_arrow(ref, cur),
      xlsx = compare_xlsx(ref, cur),
      file = {
        exists <- file.exists(ref) && file.exists(cur)
        same <- exists && identical(unname(file.info(ref)$size), unname(file.info(cur)$size))
        gm_result(same, same, exists, NA,
                  if (same) character() else "generic artifact differs")
      },
      gm_fail(sprintf("unsupported artifact type: %s", type))
    )
    result$details$path <- rel
    results[[i]] <- result
  }
  ok <- vapply(results, function(x) isTRUE(x$ok), logical(1))
  gm_result(all(ok), all(vapply(results, `[[`, logical(1), "semantic_ok")),
            all(ok), NA,
            unlist(lapply(results, function(x) x$differences), use.names = FALSE),
            list(results = results, manifest = manifest))
}

`%||%` <- function(x, y) if (is.null(x)) y else x

capture_reference <- function(workdir, snapshot_dir, artifact_paths,
                              run_legacy, metadata = list(), overwrite = FALSE) {
  stopifnot(dir.exists(workdir), is.function(run_legacy))
  if (dir.exists(snapshot_dir) && !overwrite) {
    stop("snapshot_dir already exists; use overwrite=TRUE explicitly", call. = FALSE)
  }
  dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)
  artifacts_dir <- file.path(snapshot_dir, "artifacts")
  dir.create(artifacts_dir, recursive = TRUE, showWarnings = FALSE)
  safe_rel <- function(x) {
    if (grepl("^(/|[A-Za-z]:)", x) || any(c("", "..") %in% strsplit(x, "[/\\\\]")[[1]]))
      stop("artifact paths must be relative and stay below workdir", call. = FALSE)
    x
  }
  artifact_paths <- vapply(artifact_paths, safe_rel, character(1))
  started <- Sys.time()
  run <- run_legacy()
  status <- if (is.list(run) && !is.null(run$status)) run$status else run
  stdout <- if (is.list(run)) run$stdout %||% character() else character()
  stderr <- if (is.list(run)) run$stderr %||% character() else character()
  copied <- character()
  for (rel in artifact_paths) {
    source <- file.path(workdir, rel)
    if (!file.exists(source) && !dir.exists(source)) stop("missing artifact: ", rel, call. = FALSE)
    target <- file.path(artifacts_dir, rel)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (dir.exists(source)) {
      dir.create(target, recursive = TRUE, showWarnings = FALSE)
      entries <- list.files(source, all.files = TRUE, no.. = TRUE, full.names = TRUE)
      if (length(entries) > 0L) {
        file.copy(entries, target, recursive = TRUE, overwrite = FALSE)
      }
    } else {
      file.copy(source, target, overwrite = FALSE)
    }
    copied <- c(copied, rel)
  }
  saveRDS(list(status = status, started = started, finished = Sys.time(),
               workdir = normalizePath(workdir), artifacts = copied,
               metadata = metadata), file.path(snapshot_dir, "run.rds"))
  writeLines(as.character(stdout), file.path(snapshot_dir, "stdout.log"))
  writeLines(as.character(stderr), file.path(snapshot_dir, "stderr.log"))
  if (!identical(as.integer(status), 0L)) stop("legacy run failed", call. = FALSE)
  invisible(list(snapshot_dir = snapshot_dir, artifacts = copied, status = status))
}
