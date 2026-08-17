# descriptiveStats

A small R package with six descriptive statistics functions and clearly
documented handling of edge cases. Written for Question 1 of the DSX Data
Scientist coding assessment.

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

## Edge cases

| Situation | What happens |
|---|---|
| Non-numeric `x` (character, logical, factor, list, `NULL`) | error: `` `x` must be a numeric vector, not <class>. `` |
| `na.rm` not a single `TRUE`/`FALSE` | error |
| Empty vector, or all `NA` with `na.rm = TRUE` | warning, returns `NA_real_` |
| `NA` present and `na.rm = FALSE` | `NA_real_` (same as base R) |
| Single value | returned unchanged (`calc_iqr()` returns 0) |
| Ties in `calc_mode()` | all tied values, sorted ascending |
| No mode (every value unique) | message, returns `NA_real_` |

## Note on the assessment example

The brief lists `calc_mean(data) # 3.3`, `calc_q1(data) # 2.5` and
`calc_q3(data) # 5.5` for the vector above. The arithmetic mean of that vector
is 4.3, and none of the standard quantile definitions (`stats::quantile()`
types 1 to 9) give 2.5 and 5.5. So this package implements the standard
definitions (median 4.5 and mode 5 do match the brief) and exposes the `type`
argument, so any of the nine textbook quantile algorithms can be chosen.

## Development

```r
devtools::document("question_1/descriptive_stats")
devtools::test("question_1/descriptive_stats")
devtools::check("question_1/descriptive_stats")
```
