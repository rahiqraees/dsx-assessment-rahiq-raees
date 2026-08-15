test_that("calc_median matches the brief's example data", {
  expect_equal(calc_median(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)), 4.5)
})

test_that("calc_median handles odd/even lengths and single values", {
  expect_equal(calc_median(c(3, 1, 2)), 2)
  expect_equal(calc_median(c(1, 2, 3, 4)), 2.5)
  expect_equal(calc_median(7), 7)
})

test_that("calc_median handles NA and empty input", {
  expect_true(is.na(calc_median(c(1, NA))))
  expect_equal(calc_median(c(1, NA, 5), na.rm = TRUE), 3)
  expect_warning(res <- calc_median(numeric(0)))
  expect_true(is.na(res))
})

test_that("calc_median rejects non-numeric input", {
  expect_error(calc_median(factor("a")), "must be a numeric vector, not factor")
})
