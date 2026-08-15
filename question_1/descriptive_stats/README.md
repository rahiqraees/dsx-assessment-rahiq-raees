# descriptiveStats

A small R package implementing six descriptive statistics functions with
explicit, documented handling of edge cases. Built for Question 1 of the DSX
Data Scientist coding assessment.

## Installation

From the repository root:

```r
# install.packages("devtools")
devtools::install("question_1/descriptive_stats")
library(descriptiveStats)
```

## Functions

| Function | Returns |
|---|---|
| `calc_mean(x, na.rm = FALSE)` | arithmetic mean |
| `calc_median(x, na.rm = FALSE)` | median |
| `calc_mode(x, na.rm = FALSE)` | most frequent value(s); all tied modes, ascending |
| `calc_q1(x, na.rm = FALSE, type = 7)` | first quartile (`stats::quantile`) |
| `calc_q3(x, na.rm = FALSE, type = 7)` | third quartile |
| `calc_iqr(x, na.rm = FALSE, type = 7)` | `Q3 - Q1` |

## Example

```r
data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
calc_mean(data)    # 4.3
calc_median(data)  # 4.5
calc_mode(data)    # 5
calc_q1(data)      # 2.25
calc_q3(data)      # 5
calc_iqr(data)     # 2.75
```

## Edge-case behaviour

| Situation | Behaviour |
|---|---|
| Non-numeric `x` (character, logical, factor, list, `NULL`) | error: `` `x` must be a numeric vector, not <class>. `` |
| `na.rm` not a single `TRUE`/`FALSE` | error |
| Empty vector, or all `NA` with `na.rm = TRUE` | warning + `NA_real_` |
| `NA` present and `na.rm = FALSE` | `NA_real_` (mirrors base R) |
| Single value | returned unchanged (`calc_iqr()` returns 0) |
| Ties in `calc_mode()` | all tied values, sorted ascending |
| No mode (every value unique) | message + `NA_real_` |

## Note on the assessment example

The brief lists `calc_mean(data) # 3.3`, `calc_q1(data) # 2.5` and
`calc_q3(data) # 5.5` for the vector above. The arithmetic mean of that
vector is 4.3, and no standard quantile definition (`stats::quantile()`
types 1–9) yields 2.5 / 5.5. This package implements the standard
definitions (median 4.5 and mode 5 match the brief) and exposes the `type`
argument so any of the nine textbook quantile algorithms can be selected.

## Development

```r
devtools::document("question_1/descriptive_stats")
devtools::test("question_1/descriptive_stats")
devtools::check("question_1/descriptive_stats")
```
