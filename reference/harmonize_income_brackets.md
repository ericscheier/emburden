# Harmonize Income Brackets Across Vintages

Harmonizes income bracket categories when comparing data across
different vintage years. This is necessary because some datasets
(particularly AMI) have different bracket definitions across years.

## Usage

``` r
harmonize_income_brackets(
  data,
  dataset,
  vintage,
  strict_matching = TRUE,
  comparison_vintages = NULL
)
```

## Arguments

- data:

  A data frame containing income bracket data

- dataset:

  Character, either "ami" or "fpl"

- vintage:

  Integer, the year of the data vintage

- strict_matching:

  Logical, if TRUE (default) only keeps brackets that exist in both
  vintages being compared. If FALSE, keeps all brackets.

- comparison_vintages:

  Integer vector of length 2, the vintages being compared (e.g., c(2018,
  2022)). Required when strict_matching = TRUE.

## Value

A list with components:

- `data`: The harmonized data frame

- `warnings`: Character vector of any warnings about bracket mismatches

- `dropped_brackets`: Character vector of brackets that were dropped

## Details

### Dataset-Specific Bracket Definitions

#### AMI (Area Median Income)

- **2018**: 3 brackets

  - `very_low`: Very low income (typically \<50% AMI)

  - `low_mod`: Low to moderate income (typically 50-80% AMI)

  - `mid_high`: Middle to high income (typically \>80% AMI)

- **2022**: 5 brackets

  - `very_low`: Very low income (same as 2018)

  - `low_mod`: Low to moderate income (same as 2018)

  - `mid_high`: Middle to high income (narrower than 2018)

  - `100-150%`: 100-150% of AMI (new in 2022)

  - `150%+`: Above 150% of AMI (new in 2022)

#### FPL (Federal Poverty Level)

- **Both 2018 and 2022**: 5 brackets

  - `0-100%`: Below poverty line

  - `100-150%`: 100-150% of FPL

  - `150-200%`: 150-200% of FPL

  - `200-400%`: 200-400% of FPL

  - `400%+`: Above 400% of FPL
