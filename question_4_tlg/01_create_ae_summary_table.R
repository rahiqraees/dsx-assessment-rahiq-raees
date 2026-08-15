# ------------------------------------------------------------------------------
# Question 4.1 - Summary table of treatment-emergent adverse events (TEAEs)
# Modelled on FDA Table 10 (pharmaverse cardinal catalogue).
#
# Input : pharmaverseadam::adae (TRTEMFL == "Y"), pharmaverseadam::adsl (denominators)
# Output: question_4_tlg/output/ae_summary_table.html
#
# Rows   : AESOC (System Organ Class) then AETERM, sorted by descending frequency
# Columns: ACTARM with N in the header
# Cells  : n (%) of subjects with at least one event; overall TEAE row on top
# Run from the repository root:  Rscript question_4_tlg/01_create_ae_summary_table.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(gtsummary)
  library(gt)
})

out_dir <- "question_4_tlg/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- 1. Analysis data ------------------------------------------------------
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

teae <- adae %>% filter(TRTEMFL == "Y")              # treatment-emergent records only
adsl_saf <- adsl %>% filter(SAFFL == "Y")            # denominators: safety population

# ---- 2. Hierarchical summary (SOC > preferred term) -----------------------
# tbl_hierarchical() counts distinct USUBJIDs, so a subject with repeat events of
# the same term is counted once; denominator = the safety population per arm.
tbl <- tbl_hierarchical(
  data        = teae,
  variables   = c(AESOC, AETERM),
  by          = ACTARM,
  id          = USUBJID,                # count subjects, not records
  denominator = adsl_saf,               # N per arm from ADSL
  overall_row = TRUE,                   # "any TEAE" row
  label       = list(AESOC ~ "Primary System Organ Class",
                     AETERM ~ "Reported Term for the Adverse Event")
) %>%
  sort_hierarchical(sort = "descending") %>%          # most frequent first
  # the overall row carries an internal sentinel label; give it a clinical one
  modify_table_body(~ .x %>%
    mutate(label = if_else(variable == "..ard_hierarchical_overall..",
                           "Treatment Emergent AEs", label))) %>%
  modify_header(all_stat_cols() ~ "**{level}**  \nN = {n}") %>%
  modify_caption("**Table 10. Summary of Treatment-Emergent Adverse Events by System Organ Class and Preferred Term (Safety Population)**") %>%
  modify_footnote_header("N = number of subjects in the safety population; n (%) = subjects with at least one event",
                         columns = all_stat_cols())

body <- tbl$table_body

# ---- 3. Render to gt and indent the preferred terms under their SOC --------
# gtsummary only pads the AETERM labels with literal spaces, which HTML collapses,
# so the SOC > term hierarchy would render flat. Apply a real CSS indent instead.
gt_tbl <- as_gt(tbl)

# as_gt() must preserve row order for the row indices below to address the right cells
stopifnot(identical(gt_tbl[["_data"]]$label, body$label))

term_rows <- which(body$variable == "AETERM")
stopifnot(length(term_rows) > 0)

gt_tbl <- gt_tbl %>%
  tab_style(style     = cell_text(indent = px(15)),
            locations = cells_body(columns = label, rows = term_rows))

# ---- 4. Save as HTML -------------------------------------------------------
html_path <- file.path(out_dir, "ae_summary_table.html")
gtsave(gt_tbl, html_path)

# ---- 5. Checks -------------------------------------------------------------
stopifnot(file.exists(html_path))

# 5a. Overall TEAE row: exactly one row, expected label and counts in every arm.
overall <- body[body$variable == "..ard_hierarchical_overall..", ]
stopifnot(nrow(overall) == 1L,
          overall$label   == "Treatment Emergent AEs",
          overall$stat_1  == "65 (76%)",
          overall$stat_2  == "68 (94%)",
          overall$stat_3  == "84 (88%)",
          "Treatment Emergent AEs" %in% body$label)

# 5b. Header denominators must be the safety population sizes taken from ADSL.
hdr <- tbl$table_styling$header %>%
  filter(column %in% c("stat_1", "stat_2", "stat_3")) %>%
  arrange(column)
saf_n <- adsl_saf %>% count(ACTARM) %>% arrange(ACTARM)
stopifnot(identical(hdr$modify_stat_level, as.character(saf_n$ACTARM)),
          identical(as.integer(hdr$modify_stat_n), as.integer(saf_n$n)),
          identical(as.integer(hdr$modify_stat_n), c(86L, 72L, 96L)))

# 5c. The indentation really made it into the rendered HTML (not just leading spaces).
html <- readLines(html_path, warn = FALSE)
stopifnot(nrow(gt_tbl[["_styles"]]) == length(term_rows),
          any(grepl("text-indent: 15px", html, fixed = TRUE)))

cat("Saved", html_path, "\n")
cat("Indented", length(term_rows), "preferred-term rows under", sum(body$variable == "AESOC"), "SOC rows\n")
print(head(body %>% select(variable, label, stat_1, stat_2, stat_3), 12))
