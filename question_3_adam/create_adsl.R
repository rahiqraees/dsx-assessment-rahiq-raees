# ------------------------------------------------------------------------------
# Question 3: build the ADaM ADSL (Subject-Level Analysis Dataset) with {admiral}
#
# Inputs : pharmaversesdtm::dm, vs, ex, ds, ae
# Output : question_3_adam/output/adsl.rds and adsl.csv
#
# Variables derived, following the assessment specification:
#   AGEGR9 / AGEGR9N  age groups "<18" (1), "18 - 50" (2), ">50" (3)
#   TRTSDTM / TRTSTMF first valid-dose exposure start datetime + time imputation flag
#   TRTEDTM           last valid-dose exposure end datetime (needed for LSTALVDT)
#   ITTFL             "Y" if DM.ARM populated else "N"
#   ABNSBPFL          "Y" if any SYSBP (mmHg) < 100 or >= 140 else "N"
#   LSTALVDT          last known alive date (VS / AE / DS / last treatment)
#   CARPOPFL          "Y" if any AE with AESOC == "CARDIAC DISORDERS", else NA
#
# Run from the repository root:  Rscript question_3_adam/create_adsl.R
# ------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(admiral)
  library(pharmaversesdtm)
})

out_dir <- "question_3_adam/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

# ---- 1. Start from DM ------------------------------------------------------
# ADSL has one record per subject, so DM is the natural starting point. DOMAIN
# is an SDTM-only variable and does not carry over into ADaM.
adsl <- dm %>% select(-DOMAIN)

# ---- 2. AGEGR9 / AGEGR9N ---------------------------------------------------
# Age groups: under 18 is 1, 18 to 50 inclusive is 2, over 50 is 3. The three
# conditions do not overlap and cover the whole range, so every subject with a
# non-missing AGE ends up in a group.
agegr9_lookup <- exprs(
  ~condition,             ~AGEGR9,   ~AGEGR9N,
  AGE < 18,               "<18",     1,
  AGE >= 18 & AGE <= 50,  "18 - 50", 2,
  AGE > 50,               ">50",     3
)
adsl <- adsl %>% derive_vars_cat(definition = agegr9_lookup)

# ---- 3. TRTSDTM / TRTSTMF / TRTEDTM ---------------------------------------
# A valid dose is EXDOSE > 0, or EXDOSE == 0 on a placebo treatment. Only
# records with a complete date part in EXSTDTC are used. A missing time is
# imputed to 00:00:00 for the start and 23:59:59 for the end. ignore_seconds_flag
# stops a seconds-only imputation from setting the flag, so TRTSTMF is only ever
# "H" or "M".
ex_valid <- ex %>%
  filter(
    EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO")),
    nchar(EXSTDTC) >= 10                       # complete YYYY-MM-DD date part
  ) %>%
  derive_vars_dtm(
    dtc = EXSTDTC, new_vars_prefix = "EXST",
    highest_imputation = "h", time_imputation = "first", # impute missing h/m/s
    ignore_seconds_flag = TRUE                            # seconds-only imputation sets no flag
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC, new_vars_prefix = "EXEN",
    highest_imputation = "h", time_imputation = "last",
    ignore_seconds_flag = TRUE
  )

adsl <- adsl %>%
  # first exposure by date/time is the treatment start
  derive_vars_merged(
    dataset_add = ex_valid,
    by_vars = exprs(STUDYID, USUBJID),
    order = exprs(EXSTDTM, EXSEQ), mode = "first",
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF)
  ) %>%
  # last exposure end is the treatment end (also the 4th LSTALVDT source)
  derive_vars_merged(
    dataset_add = ex_valid, filter_add = !is.na(EXENDTM),
    by_vars = exprs(STUDYID, USUBJID),
    order = exprs(EXENDTM, EXSEQ), mode = "last",
    new_vars = exprs(TRTEDTM = EXENDTM)
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM))   # TRTSDT, TRTEDT

# ---- 4. ITTFL --------------------------------------------------------------
# "Y" if the subject has a planned arm (was randomised), else "N". The rule is
# applied as written. In this study ARM is populated for every subject, and
# screen failures carry ARM == "Screen Failure", so ITTFL is "Y" throughout.
adsl <- adsl %>% mutate(ITTFL = if_else(!is.na(ARM), "Y", "N"))

# ---- 5. ABNSBPFL -----------------------------------------------------------
# "Y" if any systolic BP (VSTESTCD == "SYSBP", in mmHg) is 140 or above, or
# below 100, else "N". The specification's summary bullet mentions "supine", but
# the detailed rule has no position (VSPOS) filter, so I followed the detailed
# rule and every SYSBP record counts regardless of position. Subjects with no
# qualifying VS record at all get "N" too.
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = vs,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = ABNSBPFL,
    condition = VSTESTCD == "SYSBP" & VSSTRESU == "mmHg" &
      (VSSTRESN >= 140 | VSSTRESN < 100),
    false_value = "N", missing_value = "N"
  )

# ---- 6. LSTALVDT -----------------------------------------------------------
# Latest of: (1) a complete VS date with a valid result, (2) a complete AE start
# date, (3) a complete DS start date, (4) the date part of the last treatment
# (TRTEDT). Partial dates must never contribute, so each DTC-based event is
# limited to complete YYYY-MM-DD dates (nchar >= 10) in its condition. The check
# has to be in the condition and not only in convert_dtc_to_dt(): a partial date
# would convert to NA, and since the events are ranked by
# order = exprs(LSTALVDT, seq, event_nr) with mode = "last" (NA sorts last), that
# one partial date would win and wipe out the subject's real date.
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(dataset_name = "vs",
            condition = (!is.na(VSSTRESN) | !is.na(VSSTRESC)) & nchar(VSDTC) >= 10,
            set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(VSDTC), seq = VSSEQ)),
      event(dataset_name = "ae",
            condition = nchar(AESTDTC) >= 10,
            set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(AESTDTC), seq = AESEQ)),
      event(dataset_name = "ds",
            condition = nchar(DSSTDTC) >= 10,
            set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(DSSTDTC), seq = DSSEQ)),
      event(dataset_name = "adsl", condition = !is.na(TRTEDT),
            set_values_to = exprs(LSTALVDT = TRTEDT, seq = 0))
    ),
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT)
  )

# ---- 7. CARPOPFL -----------------------------------------------------------
# "Y" if the subject has any AE in system organ class CARDIAC DISORDERS,
# otherwise missing. The flag is only populated when the condition is met.
adsl <- adsl %>%
  derive_var_merged_exist_flag(
    dataset_add = ae,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = CARPOPFL,
    condition = toupper(AESOC) == "CARDIAC DISORDERS",
    false_value = NA_character_, missing_value = NA_character_
  )

# ---- 8. Checks -------------------------------------------------------------
stopifnot(
  nrow(adsl) == nrow(dm),
  !any(duplicated(adsl$USUBJID)),
  all(c("AGEGR9", "AGEGR9N", "TRTSDTM", "TRTSTMF", "ITTFL", "ABNSBPFL",
        "LSTALVDT", "CARPOPFL") %in% names(adsl)),
  all(adsl$TRTSTMF %in% c(NA, "H", "M")),          # never "S" (ignore_seconds_flag)
  all(adsl$ITTFL %in% c("Y", "N")),
  all(adsl$ABNSBPFL %in% c("Y", "N")),
  all(adsl$CARPOPFL %in% c("Y", NA)),
  all(is.na(adsl$TRTSDTM) | adsl$ITTFL == "Y"),
  # every subject has at least one complete date across VS / AE / DS / treatment
  !anyNA(adsl$LSTALVDT),
  # nobody can be last known alive before their treatment ended
  all(is.na(adsl$TRTEDT) | adsl$LSTALVDT >= adsl$TRTEDT)
)

# ---- 9. Save ---------------------------------------------------------------
saveRDS(adsl, file.path(out_dir, "adsl.rds"))

# write.csv() drops the time part of a POSIXct when it is midnight, so for the
# CSV the datetime columns are written as ISO 8601 text. The RDS keeps the
# native POSIXct values.
adsl_csv <- adsl %>%
  mutate(across(where(~ inherits(.x, "POSIXct")), ~ format(.x, "%Y-%m-%dT%H:%M:%S")))
write.csv(adsl_csv, file.path(out_dir, "adsl.csv"), row.names = FALSE, na = "")

cat("ADSL created:", nrow(adsl), "subjects x", ncol(adsl), "variables\n")
print(table(adsl$AGEGR9, adsl$AGEGR9N))
print(table(TRTSTMF = adsl$TRTSTMF, useNA = "ifany"))
print(table(ITTFL = adsl$ITTFL))
print(table(ABNSBPFL = adsl$ABNSBPFL))
print(table(CARPOPFL = adsl$CARPOPFL, useNA = "ifany"))
print(summary(adsl$LSTALVDT))
