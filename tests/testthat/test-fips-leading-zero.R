# Regression test for the 2026-05-29 FIPS leading-zero fix in
# R/fips_utils.R. Without `.pad_fips()`, `substr(9001, 1, 2)` returns "90"
# instead of "09" and every CT row (and any state-01-09 county passed
# numerically: AL=01, AK=02, AZ=04, AR=05, CA=06, CO=08, CT=09) is
# silently misclassified or filtered downstream.
#
# These tests pin the fix at the call sites in cache_utils.R and
# lead_data_loaders.R (both call `.extract_state_fips()` via
# `.pad_fips()`).

test_that(".pad_fips zero-pads numeric inputs", {
  # Character (already padded) — preserves
  expect_equal(emburden:::.pad_fips("09001"), "09001")
  expect_equal(emburden:::.pad_fips("37183050400"), "37183050400")

  # Numeric — leading zero must be restored
  expect_equal(emburden:::.pad_fips(9001),  "09001")  # CT — the regression
  expect_equal(emburden:::.pad_fips(1001),  "01001")  # AL
  expect_equal(emburden:::.pad_fips(2020),  "02020")  # AK
  expect_equal(emburden:::.pad_fips(4001),  "04001")  # AZ
  expect_equal(emburden:::.pad_fips(5001),  "05001")  # AR
  expect_equal(emburden:::.pad_fips(6037),  "06037")  # CA
  expect_equal(emburden:::.pad_fips(8001),  "08001")  # CO

  # Width inferred from longest input
  expect_equal(emburden:::.pad_fips(c(9, 48)), c("09", "48"))  # 2-wide
  expect_equal(emburden:::.pad_fips(c(9001, 48001)), c("09001", "48001"))  # 5-wide
})

test_that(".extract_state_fips zero-pads + extracts first 2 chars", {
  expect_equal(emburden:::.extract_state_fips("09001"), "09")
  expect_equal(emburden:::.extract_state_fips(9001),  "09")  # CT
  expect_equal(emburden:::.extract_state_fips(1001),  "01")  # AL
  expect_equal(emburden:::.extract_state_fips("37183050400"), "37")
  expect_equal(emburden:::.extract_state_fips(c(9001, 48001)), c("09", "48"))
})

test_that(".extract_county_fips zero-pads + extracts first 5 chars", {
  expect_equal(emburden:::.extract_county_fips("09001"), "09001")
  expect_equal(emburden:::.extract_county_fips(9001), "09001")
  expect_equal(emburden:::.extract_county_fips("37183050400"), "37183")
})

test_that("edge cases — empty / NA", {
  expect_equal(emburden:::.pad_fips(character(0)), character(0))
  expect_equal(emburden:::.pad_fips(NA), NA_character_)
  expect_equal(emburden:::.pad_fips(NA_integer_), NA_character_)
  expect_equal(emburden:::.extract_state_fips(NA), NA_character_)
})

test_that("cache_utils / lead_data_loaders use the padded form", {
  # Simulate the state-coverage check in cache_utils:102. With a CT geoid
  # stored as numeric (the real-world failure mode), the OLD code returned
  # state_fips containing "90" not "09"; the NEW code returns "09".
  data <- data.frame(geoid = c(9001, 9003, 6037, 48001))
  state_fips <- unique(emburden:::.extract_state_fips(data$geoid))
  expect_true("09" %in% state_fips)
  expect_false("90" %in% state_fips)  # The exact symptom of the old bug
  expect_setequal(state_fips, c("09", "06", "48"))
})
