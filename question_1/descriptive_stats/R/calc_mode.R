#' Mode (most frequent value)
#'
#' Computes the mode of a numeric vector, i.e. the value(s) that occur most
#' often.
#'
#' @inheritParams calc_mean
#'
#' @details
#' * **Ties**: when several values share the highest frequency, all of them
#'   are returned, sorted in ascending order.
#' * **No mode**: when every value occurs exactly once (and there is more
#'   than one value) the function returns `NA_real_` and emits a message.
#' * A single value is its own mode and is returned unchanged.
#' * `x` empty (or all `NA` with `na.rm = TRUE`) returns `NA_real_` with a
#'   warning; `NA` present with `na.rm = FALSE` returns `NA_real_`.
#' * Non-numeric input raises an error.
#'
#' @return A numeric vector of length one or more (ties), or `NA_real_`.
#' @examples
#' calc_mode(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)) # 5
#' calc_mode(c(3, 1, 1, 3, 2))                  # 1 3  (tie)
#' calc_mode(c(1, 2, 3))                        # NA  (no mode)
#' @export
calc_mode <- function(x, na.rm = FALSE) {
  x <- check_input(x, na.rm)
  if (length(x) == 0L) return(empty_result())
  if (anyNA(x)) return(NA_real_)
  values <- sort(unique(x))
  freq <- tabulate(match(x, values))
  if (length(values) > 1L && all(freq == 1L)) {
    message("No mode: every value occurs exactly once; returning NA.")
    return(NA_real_)
  }
  values[freq == max(freq)]
}
