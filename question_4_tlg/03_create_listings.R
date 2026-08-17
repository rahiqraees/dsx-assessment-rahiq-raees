# ------------------------------------------------------------------------------
# Question 4.3: listing of treatment-emergent adverse events by subject
# Input : pharmaverseadam::adae (TRTEMFL == "Y")
# Output: question_4_tlg/output/ae_listings.html
# Run from the repository root:  Rscript question_4_tlg/03_create_listings.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(gtsummary)
  library(gt)
})

out_dir <- "question_4_tlg/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- 1. Listing data -------------------------------------------------------
listing_data <- pharmaverseadam::adae %>%
  filter(TRTEMFL == "Y") %>%                    # treatment-emergent only
  arrange(USUBJID, ASTDT, AESEQ) %>%            # by subject then event start date
  transmute(
    USUBJID,
    TRT01A,
    AETERM,
    AESEV,
    AEREL = coalesce(AEREL, ""),
    ASTDT = format(ASTDT, "%Y-%m-%d"),
    AENDT = coalesce(format(AENDT, "%Y-%m-%d"), "")   # ongoing events have no end date
  )

# Display copy: only show the subject id and treatment on a subject's first row,
# like the sample listing does. The data copy above is kept for the checks.
listing_display <- listing_data %>%
  mutate(
    first_row = !duplicated(USUBJID),
    USUBJID   = if_else(first_row, USUBJID, ""),
    TRT01A    = if_else(first_row, TRT01A, "")
  ) %>%
  select(-first_row)

# ---- 2. gtsummary listing --------------------------------------------------
# gtsummary 2.5.1 has no tbl_listing(). as_gtsummary() wraps the data frame as it
# is, so every record is printed, and modify_header() adds the column labels.
listing <- as_gtsummary(listing_display) %>%
  modify_header(
    USUBJID ~ "Unique Subject Identifier",
    TRT01A  ~ "Description of Actual Arm",
    AETERM  ~ "Reported Term for the Adverse Event",
    AESEV   ~ "Severity/Intensity",
    AEREL   ~ "Causality",
    ASTDT   ~ "Start Date of Adverse Event",
    AENDT   ~ "End Date of Adverse Event"
  ) %>%
  modify_caption("**Listing of Treatment-Emergent Adverse Events by Subject**")

gt_listing <- as_gt(listing) %>%
  tab_options(table.font.size = px(12)) %>%
  tab_source_note("Treatment-emergent adverse events (TRTEMFL = 'Y'), sorted by subject and start date.")

html_path <- file.path(out_dir, "ae_listings.html")
gtsave(gt_listing, html_path)

# ---- 3. Checks -------------------------------------------------------------
stopifnot(
  file.exists(html_path),
  nrow(listing_data) == sum(pharmaverseadam::adae$TRTEMFL %in% "Y"),
  !is.unsorted(listing_data$USUBJID),
  identical(names(listing_display), c("USUBJID", "TRT01A", "AETERM", "AESEV", "AEREL", "ASTDT", "AENDT"))
)

# Dates ascend within every subject, and the id/arm blanking kept one labelled
# row per subject.
stopifnot(
  all(listing_data %>% group_by(USUBJID) %>% summarise(ok = !is.unsorted(ASTDT)) %>% pull(ok)),
  sum(nzchar(listing_display$USUBJID)) == n_distinct(listing_data$USUBJID)
)

# The rendered HTML contains the labelled headers and the first record.
html <- paste(readLines(html_path, warn = FALSE), collapse = "\n")
stopifnot(
  all(vapply(c("Unique Subject Identifier", "Description of Actual Arm",
               "Reported Term for the Adverse Event", "Severity/Intensity",
               "Causality", "Start Date of Adverse Event", "End Date of Adverse Event"),
             function(h) grepl(h, html, fixed = TRUE), logical(1))),
  grepl("01-701-1015", html, fixed = TRUE),
  listing_data$USUBJID[1] == "01-701-1015",
  listing_data$AETERM[1] == "APPLICATION SITE ERYTHEMA"
)

cat("Saved listing with", nrow(listing_data), "TEAE records to", out_dir, "\n")
print(head(listing_display, 5))
