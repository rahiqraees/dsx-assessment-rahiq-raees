#' Median
#'
#' Computes the median of a numeric vector.
#'
#' @inheritParams calc_mean
#'
#' @details
#' Edge cases:
#' * `x` empty (or all `NA` with `na.rm = TRUE`) returns `NA_real_` with a
#'   warning.
#' * `x` containing `NA` with `na.rm = FALSE` returns `NA_real_`.
#' * A single value is returned unchanged.
#' * Non-numeric input raises an error.
#'
#' @return A numeric scalar.
#' @examples
#' calc_median(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)) # 4.5
#' calc_median(c(3, 1, 2))                        # 2
#' @export
calc_median <- function(x, na.rm = FALSE) {
  x <- check_input(x, na.rm)
  if (length(x) == 0L) return(empty_result())
  if (anyNA(x)) return(NA_real_)
  median(x)
}
