# ------------------------------------------------------------------------------
# Question 4 (prerequisite) - export ADAE to CSV
# The Python questions (5 and 6) read data/adae.csv.
# Run from the repository root:  Rscript question_4_tlg/00_export_adae.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages(library(readr))

# ---- 1. Destination --------------------------------------------------------
# data/ sits at the repository root so the Python questions can find it.
dir.create("data", showWarnings = FALSE)

# ---- 2. Export the full ADAE ----------------------------------------------
# All 107 columns are kept: the downstream Python work selects what it needs.
# na = "" writes empty cells rather than the literal "NA".
adae <- pharmaverseadam::adae
write_csv(adae, "data/adae.csv", na = "")

# ---- 3. Checks -------------------------------------------------------------
stopifnot(
  nrow(adae) > 0,
  all(c("USUBJID", "ACTARM", "AESEV", "AETERM", "AESOC", "AEREL") %in% names(adae)),
  file.exists("data/adae.csv")
)
cat("Exported", nrow(adae), "rows and", ncol(adae), "columns to data/adae.csv\n")
