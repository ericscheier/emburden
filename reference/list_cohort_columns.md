# List Available Columns in Cohort Data

Returns column names and descriptions for LEAD cohort datasets.

## Usage

``` r
list_cohort_columns(dataset = NULL, vintage = NULL)
```

## Arguments

- dataset:

  Character, either "ami" or "fpl" (optional, affects available columns)

- vintage:

  Character, "2018" or "2022" (optional, affects available columns)

## Value

Data frame with columns: column_name, description, data_type

## Examples

``` r
list_cohort_columns()
#>               column_name                                        description
#> 1                   geoid       11-digit census tract identifier (FIPS code)
#> 2          income_bracket                            Income bracket category
#> 3              households                Number of households in this cohort
#> 4            total_income                         Total household income ($)
#> 5 total_electricity_spend                     Total electricity spending ($)
#> 6         total_gas_spend                     Total natural gas spending ($)
#> 7       total_other_spend Total other fuel spending (oil, propane, etc.) ($)
#>   data_type
#> 1 character
#> 2 character
#> 3   numeric
#> 4   numeric
#> 5   numeric
#> 6   numeric
#> 7   numeric
list_cohort_columns("ami", "2022")
#>               column_name                                        description
#> 1                   geoid       11-digit census tract identifier (FIPS code)
#> 2          income_bracket                            Income bracket category
#> 3              households                Number of households in this cohort
#> 4            total_income                         Total household income ($)
#> 5 total_electricity_spend                     Total electricity spending ($)
#> 6         total_gas_spend                     Total natural gas spending ($)
#> 7       total_other_spend Total other fuel spending (oil, propane, etc.) ($)
#>   data_type
#> 1 character
#> 2 character
#> 3   numeric
#> 4   numeric
#> 5   numeric
#> 6   numeric
#> 7   numeric
```
