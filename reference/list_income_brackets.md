# List Available Income Brackets

Returns the income brackets available for a given dataset and vintage.

## Usage

``` r
list_income_brackets(dataset = c("ami", "fpl"), vintage = "2022")
```

## Arguments

- dataset:

  Character, either "ami" or "fpl"

- vintage:

  Character, "2018" or "2022"

## Value

Character vector of income bracket labels

## Examples

``` r
list_income_brackets("ami", "2022")
#> [1] "0-30% AMI"    "30-50% AMI"   "50-80% AMI"   "80-100% AMI"  "100-120% AMI"
#> [6] "120%+ AMI"   
list_income_brackets("fpl", "2018")
#> [1] "0-100%"   "100-150%" "150-200%" "200%+"   
```
