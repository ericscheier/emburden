# Get Database Path

Returns the path to the database, with protection against accidental
deletion. For tests, use a separate test database.

## Usage

``` r
get_db_path(test = FALSE)
```

## Arguments

- test:

  Logical, whether to use test database (default FALSE)

## Value

Path to database file
