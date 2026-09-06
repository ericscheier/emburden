# Delete Database (PROTECTED)

Deletes a database with safety checks. Production database requires
explicit confirmation.

## Usage

``` r
delete_db(test = TRUE, confirm = FALSE)
```

## Arguments

- test:

  Logical, delete test database (default TRUE)

- confirm:

  Logical, must be TRUE to delete production database

## Value

Logical, TRUE if deleted successfully
