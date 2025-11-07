# Load DOE LEAD Tool Cohort Data

Load household energy burden cohort data with automatic fallback:

1.  Try local database

2.  Fall back to local CSV files

3.  Auto-download from OpenEI if neither exists

4.  Auto-import downloaded data to database for future use

## Usage

``` r
load_cohort_data(
  dataset = c("ami", "fpl"),
  states = NULL,
  vintage = "2022",
  income_brackets = NULL,
  verbose = TRUE
)
```

## Arguments

- dataset:

  Character, either "ami" (Area Median Income) or "fpl" (Federal Poverty
  Line)

- states:

  Character vector of state abbreviations to filter by (optional)

- vintage:

  Character, data vintage: "2018" or "2022" (default "2022")

- income_brackets:

  Character vector of income brackets to filter by (optional)

- verbose:

  Logical, print status messages (default TRUE)

## Value

A tibble with columns:

- geoid: Census tract identifier

- income_bracket: Income bracket label

- households: Number of households

- total_income: Total household income (\$)

- total_electricity_spend: Total electricity spending (\$)

- total_gas_spend: Total gas spending (\$)

- total_other_spend: Total other fuel spending (\$)

- Additional demographic columns depending on vintage

## Examples

``` r
if (FALSE) { # \dontrun{
# Load latest (2022) NC AMI data - auto-downloads if needed!
nc_ami <- load_cohort_data(dataset = "ami", states = "NC")

# Load specific vintage
nc_ami_2018 <- load_cohort_data(dataset = "ami", states = "NC", vintage = "2018")

# Load multiple states
southeast <- load_cohort_data(dataset = "fpl", states = c("NC", "SC", "GA"))

# Filter to specific income brackets
low_income <- load_cohort_data(
  dataset = "ami",
  states = "NC",
  income_brackets = c("0-30% AMI", "30-50% AMI")
)
} # }
```
