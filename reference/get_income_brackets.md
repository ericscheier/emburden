# Get Available Income Brackets for a Dataset and Vintage

Returns the expected income brackets for a given dataset and vintage
year. Useful for understanding what brackets are available before
running analyses.

## Usage

``` r
get_income_brackets(dataset, vintage)
```

## Arguments

- dataset:

  Character, either "ami" or "fpl"

- vintage:

  Integer, the year of the data vintage (e.g., 2018, 2022)

## Value

Character vector of income bracket names

## Examples

``` r
# Get AMI brackets for 2022
get_income_brackets("ami", 2022)
#> [1] "very_low" "low_mod"  "mid_high" "100-150%" "150%+"   

# Get FPL brackets for 2018
get_income_brackets("fpl", 2018)
#> [1] "0-100%"   "100-150%" "150-200%" "200-400%" "400%+"   
```
