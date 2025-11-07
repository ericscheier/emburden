# Process raw LEAD data into analysis-ready format with energy metrics

This is the main processing workflow that:

1.  Converts raw OpenEI data to clean format

2.  Optionally aggregates by poverty status

3.  Adds energy burden and related metrics

4.  Filters out zero-energy records

## Usage

``` r
process_lead_cohort_data(data, dataset, vintage, aggregate_poverty = FALSE)
```

## Arguments

- data:

  A data frame of raw LEAD data from OpenEI

- dataset:

  Character string indicating dataset type ("ami" or "fpl")

- vintage:

  Character string indicating ACS vintage year

- aggregate_poverty:

  Logical; if TRUE, aggregate to poverty status level

## Value

A data frame ready for analysis with all energy metrics
