# Package index

## Energy Metrics

Core functions for calculating energy burden and related ratios

- [`energy_burden_func()`](https://emburden.org/reference/energy_burden_func.md)
  : Calculate Energy Burden
- [`neb_func()`](https://emburden.org/reference/neb_func.md) : Calculate
  Net Energy Burden (NEB)
- [`ner_func()`](https://emburden.org/reference/ner_func.md) : Calculate
  Net Energy Return (Nh)
- [`eroi_func()`](https://emburden.org/reference/eroi_func.md) :
  Calculate Energy Return on Investment (EROI)
- [`dear_func()`](https://emburden.org/reference/dear_func.md) :
  Calculate Disposable Energy-Adjusted Resources (DEAR)

## Data Loading

Functions for loading LEAD Tool data

- [`load_census_tract_data()`](https://emburden.org/reference/load_census_tract_data.md)
  : Load Census Tract Data
- [`load_cohort_data()`](https://emburden.org/reference/load_cohort_data.md)
  : Load DOE LEAD Tool Cohort Data
- [`check_data_sources()`](https://emburden.org/reference/check_data_sources.md)
  : Check Available Data Sources

## Cache Management

Functions for managing data cache and database

- [`clear_dataset_cache()`](https://emburden.org/reference/clear_dataset_cache.md)
  : Clear cache for a specific dataset
- [`clear_all_cache()`](https://emburden.org/reference/clear_all_cache.md)
  : Clear all emburden cache and database

## Metadata Discovery

Functions for exploring available data structure

- [`list_income_brackets()`](https://emburden.org/reference/list_income_brackets.md)
  : List Available Income Brackets
- [`get_income_brackets()`](https://emburden.org/reference/get_income_brackets.md)
  : Get Available Income Brackets for a Dataset and Vintage
- [`list_states()`](https://emburden.org/reference/list_states.md) :
  List Available States
- [`list_cohort_columns()`](https://emburden.org/reference/list_cohort_columns.md)
  : List Available Columns in Cohort Data
- [`get_dataset_info()`](https://emburden.org/reference/get_dataset_info.md)
  : Get Dataset Information

## Statistical Analysis

Weighted aggregation and group-level calculations

- [`calculate_weighted_metrics()`](https://emburden.org/reference/calculate_weighted_metrics.md)
  : Calculate Weighted Metrics for Energy Burden Analysis
- [`compare_energy_burden()`](https://emburden.org/reference/compare_energy_burden.md)
  : Compare Energy Burden Between Years
- [`print(`*`<energy_burden_comparison>`*`)`](https://emburden.org/reference/print.energy_burden_comparison.md)
  : Print Comparison Summary

## Formatting Utilities

Format numbers for publication-ready tables

- [`to_percent()`](https://emburden.org/reference/to_percent.md) :
  Format Number as Percentage
- [`to_dollar()`](https://emburden.org/reference/to_dollar.md) : Format
  Number as Dollar Amount
- [`to_big()`](https://emburden.org/reference/to_big.md) : Format Large
  Numbers with Thousand Separators
- [`to_million()`](https://emburden.org/reference/to_million.md) :
  Format Numbers in Millions
- [`to_billion_dollar()`](https://emburden.org/reference/to_billion_dollar.md)
  : Format Dollar Amounts in Billions
- [`colorize()`](https://emburden.org/reference/colorize.md) : Colorize
  Text for Knitted Documents

## Sample Data

Bundled datasets for examples and testing

- [`orange_county_sample`](https://emburden.org/reference/orange_county_sample.md)
  : Orange County NC Energy Burden Sample Data
- [`nc_sample`](https://emburden.org/reference/nc_sample.md) : North
  Carolina Complete Energy Burden Sample Data
