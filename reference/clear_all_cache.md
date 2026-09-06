# Clear all emburden cache and database

Nuclear option: clears ALL cached data and database. Use with caution -
will require re-downloading all data.

## Usage

``` r
clear_all_cache(confirm = FALSE, verbose = TRUE)
```

## Arguments

- confirm:

  Logical, must be TRUE to proceed (safety check)

- verbose:

  Logical, print progress messages

## Value

Invisibly returns list with: cache_cleared (logical), db_cleared
(logical)

## Examples

``` r
# \donttest{
# Clear everything (requires confirm = TRUE)
clear_all_cache(confirm = TRUE)
#> Clearing ALL emburden cache and database...
#>   ✓ Deleted cache directory: ~/.cache/emburden
#> ✓ All cache and database cleared
#>   Note: Data will be re-downloaded from OpenEI on next use
# }
```
