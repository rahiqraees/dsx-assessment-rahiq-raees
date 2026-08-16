# DSX Data Scientist Coding Assessment

Solutions to the six-question assessment covering R package development, the
Pharmaverse (SDTM/ADaM/TLG) and Python (FastAPI, LangChain). Each question
lives in its own folder and runs independently from the repository root; every
generated output is committed so results can be reviewed without re-running.

## Repository layout

| Folder | Question | Deliverable | Run | Output |
|---|---|---|---|---|
| `question_1/descriptive_stats/` | 1 — R package | `descriptiveStats` package (mean, median, mode, Q1, Q3, IQR) with roxygen docs and testthat suite | `Rscript -e 'devtools::check("question_1/descriptive_stats")'` | package (`R/`, `man/`, `tests/`) |
| `question_2_sdtm/` | 2 — SDTM | `02_create_ds_domain.R` builds the DS domain from `pharmaverseraw::ds_raw` with {sdtm.oak} | `Rscript question_2_sdtm/02_create_ds_domain.R` | `output/ds.rds`, `output/ds.csv` |
| `question_3_adam/` | 3 — ADaM | `create_adsl.R` derives ADSL from SDTM with {admiral} | `Rscript question_3_adam/create_adsl.R` | `output/adsl.rds`, `output/adsl.csv` |
| `question_4_tlg/` | 4 — TLG | TEAE summary table ({gtsummary}), two plots ({ggplot2}), AE listing | `Rscript question_4_tlg/0{0,1,2,3}_*.R` | `output/ae_summary_table.html`, `output/ae_severity_by_treatment.png`, `output/top10_ae_incidence.png`, `output/ae_listings.html` |
| `question_5_api/` | 5 — Python | FastAPI service: `GET /`, `POST /ae-query`, `GET /subject-risk/{id}` | `uv run uvicorn question_5_api.main:app --reload` | — |
| `question_6_genai/` | 6 — Python | `ClinicalTrialDataAgent` (LangChain + structured output) with 3-question test script | `uv run python -m question_6_genai.run_examples` | — |
| `data/` | 4 → 5/6 | `adae.csv` exported from `pharmaverseadam::adae` by `question_4_tlg/00_export_adae.R`; input for questions 5 and 6 | — | — |

## Prerequisites

**R ≥ 4.2** (developed on R 4.6.0). Install every CRAN dependency once:

```bash
Rscript install_r_packages.R
```

Package versions used: admiral 1.5.0, sdtm.oak 0.2.0, gtsummary 2.5.1, gt 1.3.0,
ggplot2 4.0.3, dplyr 1.2.1, pharmaverseadam 1.3.0, pharmaversesdtm 1.5.0,
pharmaverseraw 0.1.1.

**Python 3.12** managed with [uv](https://docs.astral.sh/uv/):

```bash
uv sync          # creates .venv from pyproject.toml / uv.lock
```

## Running everything

```bash
# Q1 - package: document, test, check, install
Rscript -e 'devtools::document("question_1/descriptive_stats"); devtools::test("question_1/descriptive_stats"); devtools::check("question_1/descriptive_stats")'

# Q2 - SDTM DS
Rscript question_2_sdtm/02_create_ds_domain.R

# Q3 - ADaM ADSL
Rscript question_3_adam/create_adsl.R

# Q4 - TLG (00 exports data/adae.csv used by Q5/Q6)
Rscript question_4_tlg/00_export_adae.R
Rscript question_4_tlg/01_create_ae_summary_table.R
Rscript question_4_tlg/02_create_visualizations.R
Rscript question_4_tlg/03_create_listings.R

# Q5 - API (then open http://127.0.0.1:8000/docs)
uv run uvicorn question_5_api.main:app --reload

# Q6 - GenAI assistant (set ANTHROPIC_API_KEY to use the live model; mock otherwise)
uv run python -m question_6_genai.run_examples

# Python tests and lint
uv run pytest
uv run ruff check .
```

## Design notes and assumptions

**Q1 — descriptiveStats.** All functions share one validator (`check_input()`) so
errors are consistent: non-numeric input errors, empty input warns and returns
`NA`, `NA` with `na.rm = FALSE` returns `NA`, a single value is returned
unchanged. `calc_mode()` returns every tied mode (ascending) and `NA` with a
message when no value repeats. Quartiles use `stats::quantile(type = 7)` (R's
default) with `type` exposed. The brief's example prints `calc_mean = 3.3`,
`Q1 = 2.5`, `Q3 = 5.5` for `c(1,2,2,3,4,5,5,5,6,10)`; the arithmetic mean of
that vector is 4.3 and no standard quantile type gives 2.5/5.5, so the standard
definitions are implemented (median 4.5 and mode 5 match the brief).
`devtools::check()` passes with 0 errors, 0 warnings, 0 notes.

**Q2 — SDTM DS.** Follows the {sdtm.oak} AE example: `generate_oak_id_vars()`,
`assign_no_ct()` (DSTERM, VISIT), `assign_ct()` with codelist C66727 (DSDECOD),
`hardcode_no_ct()` + `condition_add()` (DSCAT: Randomized → PROTOCOL MILESTONE,
free-text "other" events → OTHER EVENT, else DISPOSITION EVENT),
`assign_datetime()` (DSDTC from date + time, DSSTDTC from date), `derive_seq()`
and `derive_study_day()` (RFSTDTC from DM). `derive_seq()` orders records within
a subject by DSSTDTC and then by eCRF collection order (`oak_id`) rather than by
DSDECOD, which reproduces the DSSEQ of `pharmaversesdtm::ds` exactly. Per the
aCRF general notes the coded term (`IT.DSTERM`/`IT.DSDECOD`) and the free-text
`OTHERSP` are mutually exclusive, so they are coalesced. VISITNUM comes from the
study's SV visit lookup. DSTERM is upper-cased to match the CDISC pilot
conventions used in `pharmaversesdtm::ds`; the output matches that reference
dataset row for row. The eCRF's collected spellings of four codelist terms
("Completed", "Study Terminated by Sponsor", "Screen Failure",
"Lost to Follow-Up") were added to the study CT's synonyms so `assign_ct()`
maps them; only Randomized, Final Lab Visit and Final Retrieval Visit fall
outside C66727 and are passed through upper-cased by {sdtm.oak}.

**Q3 — ADaM ADSL.** admiral functions are used wherever one exists:
`derive_vars_cat()` (AGEGR9/AGEGR9N, 18 and 50 inclusive in the middle group),
`derive_vars_dtm()` + `derive_vars_merged()` (TRTSDTM/TRTSTMF from the first
valid-dose exposure with hours/minutes imputed to 00 and `ignore_seconds_flag =
TRUE`; TRTEDTM from the last), `derive_var_merged_exist_flag()` (ABNSBPFL,
CARPOPFL) and `derive_vars_extreme_event()` (LSTALVDT, the current replacement
for the deprecated `derive_var_extreme_dt()`). A valid dose is `EXDOSE > 0` or
`EXDOSE == 0` with a placebo treatment. The LSTALVDT source events are
restricted to complete dates (`nchar(<DTC>) >= 10`), because a partial date
converts to `NA`, and `NA` sorts last under the `mode = "last"` ranking and
would blank the result. ABNSBPFL applies no position (VSPOS) filter: the
specification defines the flag by VSTESTCD `SYSBP` in mmHg with a value ≥ 140 or
< 100, so that rule is implemented as written. `ITTFL` applies the specification
literally (`ARM` non-missing → "Y"); in this data every subject, including
screen failures whose ARM is "Screen Failure", has ARM populated.

**Q4 — TLG.** The summary table is modelled on FDA Table 10 from the pharmaverse
cardinal catalogue, which is where its "Table 10." caption comes from. It uses
`gtsummary::tbl_hierarchical()` on TEAEs (`TRTEMFL == "Y"`) with the safety
population from ADSL as denominators, an overall "Treatment Emergent AEs" row
and descending-frequency sorting, saved via {gt}; preferred terms are indented
under their system organ class with a real gt CSS indent, and the script asserts
the column denominators (86 / 72 / 96) and the overall TEAE row. Plot 1 stacks AE
counts by severity per arm; Plot 2 shows the ten most frequent terms as the
percentage of the 217 subjects with at least one TEAE (the denominator is stated
in the subtitle) with an exact Clopper–Pearson 95% CI (`binom.test`). gtsummary
2.5 has no listing function, so the listing is built with
`gtsummary::as_gtsummary()` + `modify_header()` and rendered with {gt}, grouped
by subject and sorted by subject and start date.

**Q5 — API.** Data is loaded once at startup (`lifespan`); endpoints delegate to
pure functions in `risk.py` that are unit-tested against a small fixture. Filters
are case-insensitive and ANDed; null/missing filters are ignored; unknown values
match nothing; unknown subjects return 404. See `question_5_api/README.md`.

**Q6 — GenAI.** The schema shown to the model is built from the data itself
(actual AESEV/ACTARM/AEREL values, sample SOCs) and the LLM is forced to return
`{target_column, filter_value}` via LangChain structured output (JSON schema);
the executor applies exact matching for enumerated columns and partial matching
for terms, organ classes and USUBJID, returning the number of matching AE records
(`count`) and the unique `USUBJID`s (`subjects`). A deterministic mock backend
keeps the flow runnable without an API key. See `question_6_genai/README.md`.

## License

MIT — see `LICENSE`.
