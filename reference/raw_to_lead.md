# Process raw LEAD data into clean format

Converts raw LEAD data downloaded from OpenEI into a standardized clean
format suitable for analysis. Handles both 2016 (SH) and 2018+ ACS
vintages.

## Usage

``` r
raw_to_lead(data, vintage)
```

## Arguments

- data:

  A data frame of raw LEAD data from OpenEI

- vintage:

  Character string indicating the ACS vintage year ("2016", "2018",
  "2022", etc.)

## Value

A data frame with standardized column names:

- geoid:

  11-digit census tract GEOID as character

- state_abbr:

  2-letter state abbreviation (2018+ only)

- housing_tenure:

  Housing tenure category

- year_constructed:

  Year building was constructed category

- building_type:

  Building type category

- min_units:

  Minimum number of units in building

- detached:

  Whether building is detached (1/0)

- primary_heating_fuel:

  Primary heating fuel type

- income_bracket:

  Income bracket category (depends on dataset: AMI, FPL, etc.)

- households:

  Number of households

- income:

  Annual income

- electricity_spend:

  Annual electricity spending

- gas_spend:

  Annual gas spending

- other_spend:

  Annual other fuel spending
