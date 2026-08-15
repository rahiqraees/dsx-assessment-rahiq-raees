test_that("calc_mode matches the brief's example data", {
  expect_equal(calc_mode(c(1, 2, 2, 3, 4, 5, 5, 5, 6, 10)), 5)
})

test_that("calc_mode returns all tied modes sorted ascending", {
  expect_equal(calc_mode(c(3, 1, 1, 3, 2)), c(1, 3))
})

test_that("calc_mode returns NA with a message when there is no mode", {
  expect_message(res <- calc_mode(c(1, 2, 3, 4)), "No mode")
  expect_true(is.na(res))
})

test_that("calc_mode returns a single value unchanged", {
  expect_equal(calc_mode(9), 9)
})

test_that("calc_mode handles NA and empty input", {
  expect_true(is.na(calc_mode(c(1, 1, NA))))
  expect_equal(calc_mode(c(1, 1, NA), na.rm = TRUE), 1)
  expect_warning(res <- calc_mode(numeric(0)))
  expect_true(is.na(res))
})

test_that("calc_mode rejects non-numeric input", {
  expect_error(calc_mode(c("a", "a")), "must be a numeric vector, not character")
})
