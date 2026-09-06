# Get Dataset Information

Returns metadata about available LEAD datasets.

## Usage

``` r
get_dataset_info()
```

## Value

Data frame with dataset information

## Examples

``` r
get_dataset_info()
#>   dataset vintage                 full_name income_brackets states_available
#> 1     ami    2018   Area Median Income 2018               4               51
#> 2     ami    2022   Area Median Income 2022               6               51
#> 3     fpl    2018 Federal Poverty Line 2018               4               51
#> 4     fpl    2022 Federal Poverty Line 2022               5               51
#>   census_tracts                               source_url
#> 1       ~72,000  https://data.openei.org/submissions/573
#> 2       ~73,000 https://data.openei.org/submissions/6219
#> 3       ~72,000  https://data.openei.org/submissions/573
#> 4       ~73,000 https://data.openei.org/submissions/6219
```
