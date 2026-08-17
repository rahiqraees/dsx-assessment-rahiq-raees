# DSX Data Scientist Coding Assessment

My solutions to the six-question assessment. It covers R package development,
the Pharmaverse (SDTM, ADaM, TLG) and Python (FastAPI, LangChain). Each
question has its own folder and runs on its own from the repository root. All
generated outputs are committed, so you can review the results without
re-running anything.

## Repository layout

| Folder | Question | What it is | Run | Output |
|---|---|---|---|---|
| `question_1/descriptive_stats/` | 1 (R package) | `descriptiveStats` package: mean, median, mode, Q1, Q3, IQR, with roxygen docs and testthat tests | `Rscript -e 'devtools::check("question_1/descriptive_stats")'` | package (`R/`, `man/`, `tests/`) |
| `question_2_sdtm/` | 2 (SDTM) | `02_create_ds_domain.R` builds the DS domain from `pharmaverseraw::ds_raw` with {sdtm.oak} | `Rscript question_2_sdtm/02_create_ds_domain.R` | `output/ds.rds`, `output/ds.csv` |
| `question_3_adam/` | 3 (ADaM) | `create_adsl.R` derives ADSL from SDTM with {admiral} | `Rscript question_3_adam/create_adsl.R` | `output/adsl.rds`, `output/adsl.csv` |
| `question_4_tlg/` | 4 (TLG) | TEAE summary table ({gtsummary}), two plots ({ggplot2}), AE listing | `Rscript question_4_tlg/0{0,1,2,3}_*.R` | `output/ae_summary_table.html`, `output/ae_severity_by_treatment.png`, `output/top10_ae_incidence.png`, `output/ae_listings.html` |
| `question_5_api/` | 5 (Python) | FastAPI service: `GET /`, `POST /ae-query`, `GET /subject-risk/{id}` | `uv run uvicorn question_5_api.main:app --reload` | none (live server) |
| `question_6_genai/` | 6 (Python) | `ClinicalTrialDataAgent` (LangChain with structured output) plus a script that runs the three example questions | `uv run python -m question_6_genai.run_examples` | none (prints to console) |
| `data/` | 4, used by 5 and 6 | `adae.csv`, exported from `pharmaverseadam::adae` by `question_4_tlg/00_export_adae.R`; input for questions 5 and 6 | n/a | n/a |

## Prerequisites

**R 4.2 or newer** (I used R 4.6.0). Install the CRAN dependencies once:

```bash
Rscript install_r_packages.R
```

Package versions used: admiral 1.5.0, sdtm.oak 0.2.0, gtsummary 2.5.1, gt 1.3.0,
ggplot2 4.0.3, dplyr 1.2.1, pharmaverseadam 1.3.0, pharmaversesdtm 1.5.0,
pharmaverseraw 0.1.1.

**Python 3.12**, managed with [uv](https://docs.astral.sh/uv/):

```bash
uv sync          # creates .venv from pyproject.toml / uv.lock
```

## Running everything

```bash
# Q1 - package: document, test, check
Rscript -e 'devtools::document("question_1/descriptive_stats"); devtools::test("question_1/descriptive_stats"); devtools::check("question_1/descriptive_stats")'

# Q2 - SDTM DS
Rscript question_2_sdtm/02_create_ds_domain.R

# Q3 - ADaM ADSL
Rscript question_3_adam/create_adsl.R

# Q4 - TLG (00 exports data/adae.csv, which Q5 and Q6 read)
Rscript question_4_tlg/00_export_adae.R
Rscript question_4_tlg/01_create_ae_summary_table.R
Rscript question_4_tlg/02_create_visualizations.R
Rscript question_4_tlg/03_create_listings.R

# Q5 - API (then open http://127.0.0.1:8000/docs)
uv run uvicorn question_5_api.main:app --reload

# Q6 - GenAI assistant (set ANTHROPIC_API_KEY to use the live model, otherwise the mock is used)
uv run python -m question_6_genai.run_examples

# Python tests and lint
uv run pytest
uv run ruff check .
```

## Design notes and assumptions

### Q1: descriptiveStats

All six functions share one validator, `check_input()`, so the edge cases behave
the same everywhere: non-numeric input is an error, an empty vector warns and
returns `NA`, `NA` with `na.rm = FALSE` returns `NA`, and a single value is
returned unchanged. `calc_mode()` returns every tied mode in ascending order,
and returns `NA` with a message when no value repeats. Quartiles use
`stats::quantile(type = 7)`, which is R's default, and the `type` argument is
exposed.

One thing worth flagging: the brief's example prints `calc_mean = 3.3`,
`Q1 = 2.5` and `Q3 = 5.5` for `c(1,2,2,3,4,5,5,5,6,10)`. The arithmetic mean of
that vector is 4.3, and none of the standard quantile types give 2.5 and 5.5, so
I implemented the standard definitions. Median 4.5 and mode 5 do match the
brief. `devtools::check()` passes with 0 errors, 0 warnings and 0 notes.

### Q2: SDTM DS

The script follows the {sdtm.oak} AE example: `generate_oak_id_vars()`,
`assign_no_ct()` for DSTERM and VISIT, `assign_ct()` with codelist C66727 for
DSDECOD, `hardcode_no_ct()` plus `condition_add()` for DSCAT (Randomized becomes
PROTOCOL MILESTONE, free-text "other" events become OTHER EVENT, everything else
is DISPOSITION EVENT), `assign_datetime()` for DSDTC (date plus time) and
DSSTDTC (date only), then `derive_seq()` and `derive_study_day()` using RFSTDTC
from DM.

`derive_seq()` orders records within a subject by DSSTDTC and then by eCRF
collection order (`oak_id`) rather than by DSDECOD. That reproduces the DSSEQ of
`pharmaversesdtm::ds` exactly. The aCRF general notes say the coded term
(`IT.DSTERM` / `IT.DSDECOD`) and the free-text `OTHERSP` are mutually exclusive,
so they are coalesced. VISITNUM comes from the study's SV visit lookup. DSTERM is
upper-cased to match the CDISC pilot conventions in `pharmaversesdtm::ds`, and
the output matches that reference dataset row for row.

Four codelist terms are spelled differently on the eCRF ("Completed", "Study
Terminated by Sponsor", "Screen Failure", "Lost to Follow-Up"), so I added those
spellings to the study CT as synonyms and `assign_ct()` maps them. Only
Randomized, Final Lab Visit and Final Retrieval Visit fall outside C66727; those
are passed through upper-cased by {sdtm.oak}.

### Q3: ADaM ADSL

I used admiral functions wherever one exists: `derive_vars_cat()` for
AGEGR9/AGEGR9N (18 and 50 both fall in the middle group), `derive_vars_dtm()`
plus `derive_vars_merged()` for TRTSDTM/TRTSTMF (first valid-dose exposure, hours
and minutes imputed to 00, `ignore_seconds_flag = TRUE`) and TRTEDTM (last
exposure), `derive_var_merged_exist_flag()` for ABNSBPFL and CARPOPFL, and
`derive_vars_extreme_event()` for LSTALVDT, which is the current replacement for
the deprecated `derive_var_extreme_dt()`.

A valid dose is `EXDOSE > 0`, or `EXDOSE == 0` on a placebo treatment. The
LSTALVDT source events are restricted to complete dates (`nchar(<DTC>) >= 10`).
A partial date converts to `NA`, `NA` sorts last under the `mode = "last"`
ranking, and that would blank the result. ABNSBPFL applies no position (VSPOS)
filter: the specification defines the flag as VSTESTCD `SYSBP` in mmHg with a
value of 140 or more, or below 100, so that is what I implemented. `ITTFL`
follows the specification literally (`ARM` non-missing means "Y"). In this data
every subject has ARM populated, including screen failures whose ARM is
"Screen Failure".

### Q4: TLG

The summary table is modelled on FDA Table 10 from the pharmaverse cardinal
catalogue, which is where its "Table 10." caption comes from. It uses
`gtsummary::tbl_hierarchical()` on TEAEs (`TRTEMFL == "Y"`) with the safety
population from ADSL as denominators, an overall "Treatment Emergent AEs" row,
descending-frequency sorting, and is saved with {gt}. Preferred terms are
indented under their system organ class with a real gt CSS indent, and the
script asserts the column denominators (86 / 72 / 96) and the overall TEAE row.

Plot 1 stacks AE counts by severity per arm. Plot 2 shows the ten most frequent
terms as a percentage of the 217 subjects with at least one TEAE (the
denominator is stated in the subtitle) with an exact Clopper-Pearson 95% CI from
`binom.test`. gtsummary 2.5 has no listing function, so the listing is built
with `gtsummary::as_gtsummary()` and `modify_header()`, rendered with {gt},
grouped by subject and sorted by subject and start date.

### Q5: API

Data is loaded once at startup (`lifespan`). The endpoints delegate to pure
functions in `risk.py`, which are unit-tested against a small fixture. Filters
are case-insensitive and combined with AND. Null or missing filters are ignored,
unknown values match nothing, and unknown subjects return 404. More detail in
`question_5_api/README.md`.

### Q6: GenAI

The schema shown to the model is built from the data itself (the actual AESEV,
ACTARM and AEREL values, plus sample SOCs). The LLM has to return
`{target_column, filter_value}` through LangChain structured output (JSON
schema). The executor then applies exact matching for enumerated columns and
partial matching for terms, organ classes and USUBJID, and returns the number of
matching AE records (`count`) and the unique `USUBJID`s (`subjects`). A
deterministic mock backend keeps the whole flow runnable without an API key.
More detail in `question_6_genai/README.md`.

## License

MIT, see `LICENSE`.
