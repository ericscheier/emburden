# Aggregate LEAD data by poverty status

Consolidates LEAD cohort data by poverty status, aggregating households
and computing weighted averages for income and spending.

## Usage

``` r
lead_to_poverty(data, dataset)
```

## Arguments

- data:

  A data frame of processed LEAD data (output from raw_to_lead)

- dataset:

  Character string indicating income metric: "ami", "fpl", or "smi"

## Value

A data frame aggregated by geoid, poverty status, housing attributes
