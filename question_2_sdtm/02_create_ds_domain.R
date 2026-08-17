# ------------------------------------------------------------------------------
# Question 2: build the SDTM DS (Disposition) domain with {sdtm.oak}
#
# Inputs: pharmaverseraw::ds_raw (mock eCRF "Subject Disposition")
#         question_2_sdtm/study_ct.csv (study controlled terminology, codelist C66727)
#         pharmaversesdtm::dm (reference start date for the study day)
#         pharmaversesdtm::sv (VISIT to VISITNUM lookup)
# Output: question_2_sdtm/output/ds.rds and ds.csv
#
# Run from the repository root:  Rscript question_2_sdtm/02_create_ds_domain.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(sdtm.oak)
  library(pharmaverseraw)
  library(pharmaversesdtm)
})

out_dir <- "question_2_sdtm/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- 1. Study controlled terminology --------------------------------------
# Only codelist C66727 (Completion/Reason for Non-Completion) is needed, for
# DSDECOD. The eCRF spells four of its terms differently ("Completed", "Study
# Terminated by Sponsor", "Screen Failure", "Lost to Follow-Up"), so those
# spellings are listed in the study CT's term_synonyms column (";"-separated)
# and assign_ct() picks them up. "Randomized", "Final Lab Visit" and "Final
# Retrieval Visit" are not in C66727 at all; sdtm.oak passes them through
# upper-cased.
study_ct <- read.csv("question_2_sdtm/study_ct.csv",
                     stringsAsFactors = FALSE, na.strings = "")

# ---- 2. Raw data + oak identifier variables --------------------------------
# generate_oak_id_vars() adds oak_id, raw_source and patient_number. Every oak
# mapping function uses these to merge the target domain back onto the raw rows.
#
# The aCRF general notes say the disposition term is collected either as a coded
# item (IT.DSTERM / IT.DSDECOD) or, for "other" events, as free text in OTHERSP,
# never both. So coalesce() just picks whichever one is filled in.
ds_raw <- pharmaverseraw::ds_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ds_raw") %>%
  mutate(
    DSTERM_RAW  = toupper(coalesce(IT.DSTERM, OTHERSP)), # verbatim term, upper-cased as in the pilot study
    DSDECOD_RAW = coalesce(IT.DSDECOD, OTHERSP),         # coded term feeds the CT mapping
    VISIT_RAW   = toupper(INSTANCE)                      # eCRF visit instance becomes VISIT
  )

# ---- 3. Map topic / qualifier variables with sdtm.oak ---------------------
ds <-
  # DSTERM: verbatim disposition term (no CT)
  assign_no_ct(
    raw_dat = ds_raw, raw_var = "DSTERM_RAW", tgt_var = "DSTERM"
  ) %>%
  # DSDECOD: standardised term from codelist C66727
  assign_ct(
    raw_dat = ds_raw, raw_var = "DSDECOD_RAW", tgt_var = "DSDECOD",
    ct_spec = study_ct, ct_clst = "C66727"
  ) %>%
  # DSCAT: the category depends on the type of record
  #   Randomized                    -> PROTOCOL MILESTONE
  #   free-text "other" event       -> OTHER EVENT
  #   any other coded disposition   -> DISPOSITION EVENT
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, IT.DSDECOD == "Randomized"),
    raw_var = "IT.DSDECOD", tgt_var = "DSCAT", tgt_val = "PROTOCOL MILESTONE"
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, is.na(IT.DSDECOD) & !is.na(OTHERSP)),
    raw_var = "OTHERSP", tgt_var = "DSCAT", tgt_val = "OTHER EVENT"
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(IT.DSDECOD) & IT.DSDECOD != "Randomized"),
    raw_var = "IT.DSDECOD", tgt_var = "DSCAT", tgt_val = "DISPOSITION EVENT"
  ) %>%
  # DSDTC: collection date and time (DSDTCOL is mm-dd-yyyy, DSTMCOL is HH:MM)
  assign_datetime(
    raw_dat = ds_raw, raw_var = c("DSDTCOL", "DSTMCOL"), tgt_var = "DSDTC",
    raw_fmt = list(list("m-d-y"), list("H:M")), .warn = FALSE
  ) %>%
  # DSSTDTC: start date of the disposition event (IT.DSSTDAT, mm-dd-yyyy)
  assign_datetime(
    raw_dat = ds_raw, raw_var = "IT.DSSTDAT", tgt_var = "DSSTDTC",
    raw_fmt = "m-d-y", .warn = FALSE
  ) %>%
  # VISIT: eCRF instance name
  assign_no_ct(
    raw_dat = ds_raw, raw_var = "VISIT_RAW", tgt_var = "VISIT"
  )

# ---- 4. Identifiers, VISITNUM, DSSEQ, DSSTDY ------------------------------
visit_lookup <- pharmaversesdtm::sv %>% distinct(VISIT, VISITNUM)

ds <- ds %>%
  mutate(
    STUDYID = "CDISCPILOT01",
    DOMAIN  = "DS",
    USUBJID = paste0("01-", patient_number),  # study prefix + site-subject number
    DSDTC   = as.character(DSDTC),
    DSSTDTC = as.character(DSSTDTC),
    DSSTDTC_CHR = DSSTDTC                     # derive_study_day() coerces to Date; keep ISO text
  ) %>%
  left_join(visit_lookup, by = "VISIT") %>%
  # DSSEQ: sequence number within subject. Records are ordered by start date,
  # then by eCRF collection order (oak_id) for records on the same date, since
  # the disposition event is always captured before its related "other" event.
  derive_seq(tgt_var = "DSSEQ", rec_vars = c("USUBJID", "DSSTDTC", "oak_id")) %>%
  # DSSTDY: study day relative to DM.RFSTDTC (NA for screen failures, who have no RFSTDTC)
  derive_study_day(
    dm_domain = pharmaversesdtm::dm, tgdt = "DSSTDTC", refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  mutate(DSSTDTC = DSSTDTC_CHR) %>%
  select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
         VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY) %>%
  arrange(USUBJID, DSSEQ)

# ---- 5. Checks -------------------------------------------------------------
stopifnot(
  nrow(ds) == nrow(pharmaverseraw::ds_raw),
  identical(names(ds), c("STUDYID", "DOMAIN", "USUBJID", "DSSEQ", "DSTERM", "DSDECOD",
                         "DSCAT", "VISITNUM", "VISIT", "DSDTC", "DSSTDTC", "DSSTDY")),
  !anyNA(ds$DSDECOD), !anyNA(ds$DSCAT), !anyNA(ds$VISITNUM),
  !anyNA(ds$DSSTDTC), !anyNA(ds$DSDTC),
  all(ds$DSDECOD %in% c(study_ct$term_value, "RANDOMIZED",
                        "FINAL LAB VISIT", "FINAL RETRIEVAL VISIT")),
  all(ds$USUBJID %in% pharmaversesdtm::dm$USUBJID),
  !any(duplicated(ds[c("USUBJID", "DSSEQ")]))
)

# ---- 6. Save ---------------------------------------------------------------
saveRDS(ds, file.path(out_dir, "ds.rds"))
write.csv(ds, file.path(out_dir, "ds.csv"), row.names = FALSE, na = "")

cat("DS domain created:", nrow(ds), "rows x", ncol(ds), "columns\n")
print(table(ds$DSCAT))
print(head(as.data.frame(ds), 10))
