#' Validate input for the calc_* functions
#'
#' Checks that `x` is a numeric vector and that `na.rm` is a single logical,
#' then optionally strips missing values. Shared by every exported function so
#' that error messages are consistent.
#'
#' @param x Object supplied by the caller.
#' @param na.rm Logical flag supplied by the caller.
#' @return `x`, with `NA` values removed when `na.rm = TRUE`.
#' @keywords internal
#' @noRd
check_input <- function(x, na.rm) {
  if (is.null(x) || !is.numeric(x)) {
    stop(
      sprintf(
        "`x` must be a numeric vector, not %s.",
        if (is.null(x)) "NULL" else paste(class(x), collapse = "/")
      ),
      call. = FALSE
    )
  }
  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm)) {
    stop("`na.rm` must be a single TRUE or FALSE.", call. = FALSE)
  }
  if (na.rm) x[!is.na(x)] else x
}

#' Result for an empty input
#'
#' Emits a warning and returns `NA_real_`. Called when `x` has no
#' (non-missing) values left.
#' @return `NA_real_`
#' @keywords internal
#' @noRd
empty_result <- function() {
  warning("`x` contains no non-missing values; returning NA.", call. = FALSE)
  NA_real_
}

#' @importFrom stats median quantile
NULL
