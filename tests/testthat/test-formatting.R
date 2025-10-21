test_that("to_dollar formats correctly", {
  # Basic formatting
  expect_equal(to_dollar(1000), "$1,000")
  # Note: largest_with_cents=10 means only values < 10 show cents
  expect_equal(to_dollar(2500.50), "$2,500")  # Rounds to nearest dollar
  expect_equal(to_dollar(5.50), "$5.50")  # Small values show cents
  expect_equal(to_dollar(10000), "$10,000")

  # LaTeX escaped
  latex_result <- to_dollar(1000, latex = TRUE)
  expect_true(grepl("\\\\\\$", latex_result))

  # Vector inputs
  result <- to_dollar(c(1000, 2500, 10000))
  expect_length(result, 3)

  # NA handling
  expect_equal(to_dollar(NA), "")

  # Zero
  expect_equal(to_dollar(0), "$0")
})

test_that("to_percent formats correctly", {
  # Basic formatting (proportions to percentages)
  expect_equal(to_percent(0.25), "25%")
  expect_equal(to_percent(0.50), "50%")
  expect_equal(to_percent(0.123), "12%")

  # LaTeX escaped
  latex_result <- to_percent(0.25, latex = TRUE)
  expect_true(grepl("\\\\%", latex_result))

  # Vector inputs
  result <- to_percent(c(0.25, 0.50, 0.75))
  expect_length(result, 3)

  # NA handling
  expect_equal(to_percent(NA), "")

  # Edge cases
  expect_equal(to_percent(0), "0%")
  expect_equal(to_percent(1), "100%")
})

test_that("to_big formats correctly", {
  # Thousand separators
  expect_equal(to_big(1000), "1,000")
  expect_equal(to_big(25000), "25,000")
  expect_equal(to_big(1000000), "1,000,000")

  # No decimals
  result <- to_big(1234.56)
  expect_false(grepl("\\.", result))

  # NA handling
  expect_equal(to_big(NA), "")

  # Negative numbers
  expect_true(grepl("-", to_big(-1000)))
})

test_that("to_million formats correctly", {
  # Values less than 1 million
  expect_true(grepl("k$", to_million(5000)))

  # Values in millions
  result <- to_million(2500000)
  expect_true(grepl("million", result))

  # NA handling
  expect_equal(to_million(NA), "")
})

test_that("to_billion_dollar formats correctly", {
  # Values less than 1 billion
  result <- to_billion_dollar(5000000)
  expect_true(grepl("\\$", result))
  expect_true(grepl("m$", result))

  # Values in billions
  result <- to_billion_dollar(2500000000)
  expect_true(grepl("\\$", result))
  expect_true(grepl("billion", result))

  # NA handling
  expect_equal(to_billion_dollar(NA), "")
})

test_that("colorize works without knitr", {
  # Without knitr loaded, should return unchanged text
  result <- colorize("test text", "red")
  expect_type(result, "character")
})
