data <- c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)

test_that("quartiles use R's default quantile type 7", {
  expect_equal(calc_q1(data), unname(quantile(data, 0.25)))
  expect_equal(calc_q3(data), unname(quantile(data, 0.75)))
  expect_equal(calc_q1(data), 2.25)
  expect_equal(calc_q3(data), 5)
  expect_equal(calc_iqr(data), 2.75)
})

test_that("type argument is passed through to quantile", {
  expect_equal(calc_q1(data, type = 6), unname(quantile(data, 0.25, type = 6)))
  expect_equal(calc_iqr(data, type = 6),
               unname(diff(quantile(data, c(0.25, 0.75), type = 6))))
})

test_that("quartiles handle NA, empty and single values", {
  expect_true(is.na(calc_q1(c(1, NA))))
  expect_equal(calc_q3(c(1, NA, 3, 5), na.rm = TRUE), 4)
  expect_warning(res <- calc_iqr(numeric(0)))
  expect_true(is.na(res))
  expect_equal(calc_q1(5), 5)
  expect_equal(calc_q3(5), 5)
  expect_equal(calc_iqr(5), 0)
})

test_that("quartiles reject non-numeric input", {
  expect_error(calc_q1("1"), "must be a numeric vector, not character")
  expect_error(calc_iqr(list(1, 2)), "must be a numeric vector, not list")
})
