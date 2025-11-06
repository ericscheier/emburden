test_that("raw_to_lead processes 2018 data correctly", {
  # Create mock 2018+ format raw data
  # Note: BLD uses numeric range format that the function expects
  raw_data <- data.frame(
    FIP = c("37183020100", "37051003400"),
    ABV = c("NC", "NC"),
    TEN = c("OWNER", "RENTER"),
    YBL6 = c("2000-2009", "1990-1999"),
    BLD = c("1 1 DETACHED", "2 4"),  # Numeric ranges: "1-1" and "2-4"
    HFL = c("Natural gas", "Electricity"),
    AMI68 = c("0-30% AMI", "30-50% AMI"),
    UNITS = c(100, 150),
    HINCP = c(25000, 35000),
    ELEP = c(1200, 1500),
    GASP = c(800, 0),
    FULP = c(200, 100)
  )

  result <- raw_to_lead(raw_data, "2018")

  # Check column names are standardized
  expect_true("geoid" %in% names(result))
  expect_true("state_abbr" %in% names(result))
  expect_true("income_bracket" %in% names(result))
  expect_true("households" %in% names(result))

  # Check geoid is properly formatted (11 digits)
  expect_equal(nchar(result$geoid[1]), 11)
  expect_equal(result$geoid[1], "37183020100")

  # Check min_units and detached are extracted
  expect_true("min_units" %in% names(result))
  expect_true("detached" %in% names(result))
  expect_equal(result$detached[1], 1)  # Has DETACHED keyword
  expect_equal(result$detached[2], 0)  # No DETACHED keyword

  # Check data values
  expect_equal(result$households, c(100, 150))
  expect_equal(result$income, c(25000, 35000))
})

test_that("raw_to_lead handles short geoids with padding", {
  raw_data <- data.frame(
    FIP = c("1234567890", "123456789"),  # 10 and 9 digits
    ABV = c("NC", "NC"),
    TEN = c("OWNER", "OWNER"),
    YBL6 = c("2000-2009", "2000-2009"),
    BLD = c("1 1 DETACHED", "1 1 DETACHED"),
    HFL = c("Natural gas", "Electricity"),
    AMI68 = c("0-30% AMI", "30-50% AMI"),
    UNITS = c(100, 150),
    HINCP = c(25000, 35000),
    ELEP = c(1200, 1500),
    GASP = c(800, 0),
    FULP = c(200, 100)
  )

  result <- raw_to_lead(raw_data, "2018")

  # All geoids should be 11 digits with zero padding
  expect_equal(result$geoid[1], "01234567890")
  expect_equal(result$geoid[2], "00123456789")
})

test_that("raw_to_lead rejects 2016 vintage", {
  raw_data <- data.frame(FIP = "37183020100")

  expect_error(
    raw_to_lead(raw_data, "2016"),
    "2016 vintage processing not fully implemented"
  )
})

test_that("lead_to_poverty creates binary poverty indicator for FPL", {
  # Mock processed LEAD data
  data <- data.frame(
    geoid = rep("37183020100", 4),
    primary_heating_fuel = rep("Natural gas", 4),
    income_bracket = c("0-100%", "100-150%", "150-200%", "200%+"),
    households = c(50, 75, 100, 125),
    income = c(15000, 30000, 45000, 75000),
    electricity_spend = c(1200, 1400, 1600, 1800),
    gas_spend = c(800, 900, 1000, 1100),
    other_spend = c(100, 150, 200, 250),
    min_units = c(1, 1, 1, 1),
    detached = c(1, 1, 1, 1),
    housing_tenure = rep("OWNER", 4),
    year_constructed = rep("2000-2009", 4),
    building_type = rep("1 1 DETACHED", 4)
  )

  result <- lead_to_poverty(data, "fpl")

  # Check poverty indicator was created
  expect_true("income_bracket" %in% names(result))
  expect_true(is.factor(result$income_bracket))

  # Check levels
  poverty_levels <- levels(result$income_bracket)
  expect_true("Below Federal Poverty Line" %in% poverty_levels)
  expect_true("Above Federal Poverty Line" %in% poverty_levels)

  # Check aggregation occurred
  expect_true(nrow(result) <= nrow(data))
})

test_that("lead_to_poverty creates binary poverty indicator for AMI", {
  data <- data.frame(
    geoid = rep("37183020100", 3),
    primary_heating_fuel = rep("Natural gas", 3),
    income_bracket = c("very_low", "low_mod", "mid_high"),
    households = c(50, 75, 100),
    income = c(15000, 35000, 60000),
    electricity_spend = c(1200, 1400, 1600),
    gas_spend = c(800, 900, 1000),
    other_spend = c(100, 150, 200),
    min_units = c(1, 1, 1),
    detached = c(1, 1, 1),
    housing_tenure = rep("OWNER", 3),
    year_constructed = rep("2000-2009", 3),
    building_type = rep("1 1 DETACHED", 3)
  )

  result <- lead_to_poverty(data, "ami")

  # Check levels
  poverty_levels <- levels(result$income_bracket)
  expect_true("Below AMI Poverty Line" %in% poverty_levels)
  expect_true("Above AMI Poverty Line" %in% poverty_levels)
})

test_that("lead_to_poverty consolidates housing tenure", {
  data <- data.frame(
    geoid = rep("37183020100", 2),
    primary_heating_fuel = rep("Natural gas", 2),
    income_bracket = c("0-100%", "100-150%"),
    housing_tenure = c("OWNER", "RENTER"),
    households = c(50, 75),
    income = c(15000, 30000),
    electricity_spend = c(1200, 1400),
    gas_spend = c(800, 900),
    other_spend = c(100, 150),
    min_units = c(1, 1),
    detached = c(1, 1),
    year_constructed = rep("2000-2009", 2),
    building_type = rep("1 1 DETACHED", 2)
  )

  result <- lead_to_poverty(data, "fpl")

  # Check housing tenure was recoded
  expect_true(is.factor(result$housing_tenure))
  expect_true(all(result$housing_tenure %in% c("owned", "rented")))
})

test_that("lead_to_poverty creates number_of_units category", {
  data <- data.frame(
    geoid = rep("37183020100", 2),
    primary_heating_fuel = rep("Natural gas", 2),
    income_bracket = c("0-100%", "100-150%"),
    housing_tenure = rep("OWNER", 2),
    min_units = c(1, 5),  # Single vs multi-family
    detached = c(1, 0),
    households = c(50, 75),
    income = c(15000, 30000),
    electricity_spend = c(1200, 1400),
    gas_spend = c(800, 900),
    other_spend = c(100, 150),
    year_constructed = rep("2000-2009", 2),
    building_type = rep("1 1 DETACHED", 2)
  )

  result <- lead_to_poverty(data, "fpl")

  # Check number_of_units was created
  expect_true("number_of_units" %in% names(result))
  expect_true(is.factor(result$number_of_units))
  expect_true(all(result$number_of_units %in% c("single-family", "multi-family")))
})

test_that("process_lead_cohort_data calculates energy_burden correctly", {
  raw_data <- data.frame(
    FIP = c("37183020100", "37051003400"),
    ABV = c("NC", "NC"),
    TEN = c("OWNER", "RENTER"),
    YBL6 = c("2000-2009", "1990-1999"),
    BLD = c("1 1 DETACHED", "2 4"),
    HFL = c("Natural gas", "Electricity"),
    AMI68 = c("0-30% AMI", "30-50% AMI"),
    UNITS = c(100, 150),
    HINCP = c(50000, 40000),
    ELEP = c(1200, 1500),
    GASP = c(800, 0),
    FULP = c(200, 100)
  )

  result <- process_lead_cohort_data(raw_data, "ami", "2018", aggregate_poverty = FALSE)

  # Check energy_cost was calculated
  expect_true("energy_cost" %in% names(result))
  expect_equal(result$energy_cost[1], 1200 + 800 + 200)  # 2200
  expect_equal(result$energy_cost[2], 1500 + 0 + 100)    # 1600

  # Check energy_burden was calculated
  expect_true("energy_burden" %in% names(result))
  expect_equal(result$energy_burden[1], 2200 / 50000)
  expect_equal(result$energy_burden[2], 1600 / 40000)
})

test_that("process_lead_cohort_data filters zero-energy records", {
  raw_data <- data.frame(
    FIP = c("37183020100", "37051003400", "37119000100"),
    ABV = c("NC", "NC", "NC"),
    TEN = c("OWNER", "RENTER", "OWNER"),
    YBL6 = c("2000-2009", "1990-1999", "2010-2019"),
    BLD = rep("1 1 DETACHED", 3),
    HFL = rep("Natural gas", 3),
    AMI68 = rep("0-30% AMI", 3),
    UNITS = c(100, 150, 200),
    HINCP = c(50000, 40000, 60000),
    ELEP = c(1200, 0, 1800),
    GASP = c(800, 0, 900),
    FULP = c(200, 0, 0)  # Second record has zero energy
  )

  result <- process_lead_cohort_data(raw_data, "ami", "2018", aggregate_poverty = FALSE)

  # Should have filtered out the zero-energy record
  expect_equal(nrow(result), 2)
  expect_false("37051003400" %in% result$geoid)
})

test_that("process_lead_cohort_data handles aggregate_poverty = TRUE", {
  raw_data <- data.frame(
    FIP = rep("37183020100", 4),
    ABV = rep("NC", 4),
    TEN = rep("OWNER", 4),
    YBL6 = rep("2000-2009", 4),
    BLD = rep("1 1 DETACHED", 4),
    HFL = rep("Natural gas", 4),
    FPL15 = c("0-100%", "100-150%", "150-200%", "200%+"),
    UNITS = c(50, 75, 100, 125),
    HINCP = c(15000, 30000, 45000, 75000),
    ELEP = c(1200, 1400, 1600, 1800),
    GASP = c(800, 900, 1000, 1100),
    FULP = c(100, 150, 200, 250)
  )

  result <- process_lead_cohort_data(raw_data, "fpl", "2018", aggregate_poverty = TRUE)

  # Should have aggregated to poverty status level
  expect_true(nrow(result) < 4)
  expect_true("income_bracket" %in% names(result))

  # Check poverty labels were applied
  poverty_levels <- unique(as.character(result$income_bracket))
  expect_true(any(grepl("Poverty Line", poverty_levels)))
})

test_that("process_lead_cohort_data handles NA income gracefully", {
  raw_data <- data.frame(
    FIP = c("37183020100", "37051003400"),
    ABV = c("NC", "NC"),
    TEN = c("OWNER", "RENTER"),
    YBL6 = c("2000-2009", "1990-1999"),
    BLD = rep("1 1 DETACHED", 2),
    HFL = rep("Natural gas", 2),
    AMI68 = rep("0-30% AMI", 2),
    UNITS = c(100, 150),
    HINCP = c(NA, 40000),  # NA income
    ELEP = c(1200, 1500),
    GASP = c(800, 0),
    FULP = c(200, 100)
  )

  result <- process_lead_cohort_data(raw_data, "ami", "2018", aggregate_poverty = FALSE)

  # Check NA handling
  expect_true(is.na(result$energy_burden[1]))
  expect_false(is.na(result$energy_burden[2]))
})
