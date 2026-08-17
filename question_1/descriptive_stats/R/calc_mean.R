#' Arithmetic mean
#'
#' Computes the arithmetic mean of a numeric vector.
#'
#' @param x A numeric vector.
#' @param na.rm Logical. Should missing values be removed before computing?
#'   Defaults to `FALSE`.
#'
#' @details
#' Edge cases:
#' * `x` empty (or all `NA` with `na.rm = TRUE`) returns `NA_real_` with a
#'   warning.
#' * `x` containing `NA` with `na.rm = FALSE` returns `NA_real_` (same as
#'   base R).
#' * A single value is returned unchanged.
#' * Non-numeric input (character, logical, factor, `NULL`) raises an error.
#'
#' @return A numeric scalar.
#' @examples
#' calc_mean(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)) # 4.3
#' calc_mean(c(1, NA, 3), na.rm = TRUE)         # 2
#' calc_mean(c(1, NA, 3))                       # NA
#' @export
calc_mean <- function(x, na.rm = FALSE) {
  x <- check_input(x, na.rm)
  if (length(x) == 0L) return(empty_result())
  if (anyNA(x)) return(NA_real_)
  mean(x)
}
