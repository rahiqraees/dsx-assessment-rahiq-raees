# install_r_packages.R
# Installs every CRAN package used by questions 1-4. Run once from the repo root:
#   Rscript install_r_packages.R
pkgs <- c(
  # tidyverse / utilities
  "dplyr", "tidyr", "stringr", "readr", "purrr", "tibble", "lubridate",
  # pharmaverse
  "admiral", "sdtm.oak", "pharmaverseraw", "pharmaversesdtm", "pharmaverseadam",
  # tables & graphics
  "gtsummary", "gt", "ggplot2",
  # package development
  "devtools", "roxygen2", "testthat", "usethis"
)
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing) > 0) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All required packages are already installed.")
}
