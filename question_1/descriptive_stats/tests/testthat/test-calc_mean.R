test_that("calc_mean matches the brief's example data", {
  data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)
  expect_equal(calc_mean(data), 4.3)
})

test_that("calc_mean handles NA according to na.rm", {
  expect_true(is.na(calc_mean(c(1, NA, 3))))
  expect_equal(calc_mean(c(1, NA, 3), na.rm = TRUE), 2)
})

test_that("calc_mean warns and returns NA on empty input", {
  expect_warning(res <- calc_mean(numeric(0)), "no non-missing values")
  expect_true(is.na(res))
  expect_warning(res2 <- calc_mean(c(NA_real_, NA_real_), na.rm = TRUE))
  expect_true(is.na(res2))
})

test_that("calc_mean returns a single value unchanged", {
  expect_equal(calc_mean(42), 42)
})

test_that("calc_mean rejects non-numeric input with an informative error", {
  expect_error(calc_mean("a"), "must be a numeric vector, not character")
  expect_error(calc_mean(NULL), "must be a numeric vector, not NULL")
  expect_error(calc_mean(c(TRUE, FALSE)), "must be a numeric vector, not logical")
  expect_error(calc_mean(1:3, na.rm = NA), "`na.rm` must be a single TRUE or FALSE")
})

test_that("calc_mean works with integers and Inf", {
  expect_equal(calc_mean(1:4), 2.5)
  expect_equal(calc_mean(c(1, Inf)), Inf)
})
