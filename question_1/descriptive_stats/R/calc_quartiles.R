#' Quartiles and interquartile range
#'
#' `calc_q1()` returns the first quartile (25th percentile), `calc_q3()` the
#' third quartile (75th percentile) and `calc_iqr()` their difference
#' (`Q3 - Q1`). All three use [stats::quantile()] and default to its
#' `type = 7` definition (R's default).
#'
#' @inheritParams calc_mean
#' @param type Integer between 1 and 9 selecting the quantile algorithm; see
#'   [stats::quantile()]. Defaults to 7.
#'
#' @details
#' Edge cases:
#' * `x` empty (or all `NA` with `na.rm = TRUE`) returns `NA_real_` with a
#'   warning.
#' * `x` containing `NA` with `na.rm = FALSE` returns `NA_real_`.
#' * A single value: `calc_q1()` and `calc_q3()` return it unchanged and
#'   `calc_iqr()` returns 0.
#' * Non-numeric input raises an error.
#'
#' Note: the assessment brief's example lists Q1 = 2.5 and Q3 = 5.5 for
#' `c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)`. None of the standard `quantile()` types
#' give those values (type 7 gives 2.25 and 5), so this package follows the
#' standard definitions and exposes `type` so callers can pick one.
#'
#' @return A numeric scalar.
#' @examples
#' data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
#' calc_q1(data)  # 2.25
#' calc_q3(data)  # 5
#' calc_iqr(data) # 2.75
#' @name quartiles
NULL

#' @rdname quartiles
#' @export
calc_q1 <- function(x, na.rm = FALSE, type = 7) {
  quartile_impl(x, na.rm, probs = 0.25, type = type)
}

#' @rdname quartiles
#' @export
calc_q3 <- function(x, na.rm = FALSE, type = 7) {
  quartile_impl(x, na.rm, probs = 0.75, type = type)
}

#' @rdname quartiles
#' @export
calc_iqr <- function(x, na.rm = FALSE, type = 7) {
  x <- check_input(x, na.rm)
  if (length(x) == 0L) return(empty_result())
  if (anyNA(x)) return(NA_real_)
  q <- quantile(x, probs = c(0.25, 0.75), type = type, names = FALSE)
  q[2] - q[1]
}

# Shared implementation behind calc_q1() and calc_q3() (not exported).
quartile_impl <- function(x, na.rm, probs, type) {
  x <- check_input(x, na.rm)
  if (length(x) == 0L) return(empty_result())
  if (anyNA(x)) return(NA_real_)
  quantile(x, probs = probs, type = type, names = FALSE)
}
