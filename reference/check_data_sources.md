# Check Available Data Sources

Check which data sources are available locally (database, CSV files, or
will require download from OpenEI).

## Usage

``` r
check_data_sources(verbose = TRUE)
```

## Arguments

- verbose:

  Logical, print detailed status (default TRUE)

## Value

A list with status of each data source

## Examples

``` r
# \donttest{
# Check what data is available
check_data_sources()
#> 
#> Data Source Status
#> ============================================================ 
#> 
#> Local database:
#>   ✗ Not found
#> 
#> CSV Files (data/):
#>   ✗ No CSV files found
#> 
#> ⚠ No local data found. Data will be downloaded from OpenEI on first use.
#> 
# }
```
