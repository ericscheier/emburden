# \pkg{emburden}: Temporal Analysis of Household Energy Burden Using Net Energy Return Metrics,emburden: Temporal Analysis of Household Energy Burden Using Net Energy Return Metrics,\pkg{emburden}: Temporal Energy Burden Analysis

Abstract

Energy burden—the proportion of household income spent on energy—is a
critical metric for understanding energy poverty and inequity. However,
traditional energy burden ratios present analytical challenges including
difficulties with aggregation and visualization of extreme values. The
package for implements Net Energy Return (Nh) methodology to address
these limitations while enabling temporal analysis of household energy
characteristics. This paper introduces the package’s design and
demonstrates its application to comparing Low-Income Energy
Affordability Data (LEAD) Tool vintages from 2018 and 2022 across
geographic and demographic dimensions. The package provides functions
for downloading, processing, and analyzing census tract-level energy
burden data for all U.S. states, with particular attention to proper
weighted aggregation and schema normalization across data vintages. We
demonstrate the package’s capabilities through examples ranging from
state-level summaries to fine-grained census tract comparisons,
illustrating how policy-relevant insights can be extracted at multiple
scales.

## Introduction

Household energy affordability is a persistent challenge affecting
millions of households in the United States. Low-income households face
disproportionate energy burdens, often spending more than 6% of their
income on energy costs compared to 2-3% for higher-income households
(Ross, Drehobl, and Stickles 2018; Drehobl and Ross 2016). Understanding
these disparities and tracking changes over time is essential for
designing effective energy assistance programs and policies.

The traditional energy burden metric—the ratio of energy expenditures
($S$) to gross income ($G$)—has several analytical limitations. As a
ratio with income in the denominator, energy burden ($E_{b} = S/G$)
approaches infinity for households with very low incomes, creating
challenges for aggregation and visualization. Additionally, the metric
requires harmonic mean aggregation rather than arithmetic means, which
is not widely understood or consistently applied (Scheier and Kittner
2022).

### Mathematical foundations

The package for addresses these challenges by implementing Net Energy
Return (NER) methodology, adapted from macro-energy systems analysis
(Hall, Lambert, and Balogh 2011; Brandt, Dale, and Barnhart 2013;
Carbajales-Dale et al. 2014). Net energy analysis estimates the net
energy return of a process as a relationship between gross resources
extracted and embodied energy directed toward extraction:

$$G = Gross\ Resource\ Extracted$$

$$S = Spending\ on\ Extraction\ Process$$

$$Net\ Energy\ Return\ (NER) = \frac{G - S}{S}$$

For households extracting income from the economy, these ratios become:

$$G_{income} = Gross\ Income$$

$$S_{energy} = Spending\ on\ Energy$$

$$NER_{household} = \frac{G_{income} - S_{energy}}{S_{energy}}$$

This metric represents the net earnings a household receives for every
dollar of expenditure on secondary energy. For notational simplicity, we
use $N_{h}$ to denote household Net Energy Return throughout this paper,
where $N_{h} = NER_{household}$.

#### Comparison with energy burden

Energy burden, the traditional metric in energy poverty analysis, is
defined as:

$$Energy\ Burden = E_{b} = \frac{S_{energy}}{G_{income}}$$

While energy burden is intuitive as a percentage, it has several
mathematical limitations. The Net Energy Return transformation addresses
these by preventing double-counting of energy expenditures (income in
the numerator already includes the portion spent on energy) and enabling
proper weighted mean aggregation:

$$\overline{N_{h}} = \frac{\sum\left( N_{h} \times households \right)}{\sum households}$$

In contrast, energy burden requires harmonic mean aggregation:

$$\overline{E_{b}} = \frac{1}{\overline{1/E_{b}}}$$

The two metrics are mathematically related through the transformation
$E_{b} = 1/\left( N_{h} + 1 \right)$, allowing seamless conversion
between representations.

#### Energy poverty threshold

Energy poverty is commonly defined as spending greater than 10% of
household income on energy (Bednar and Reames 2020):

$$E_{b}^{*} = \frac{S_{energy}}{G_{income}} > 10\%$$

Translated to Net Energy Return, the energy poverty threshold becomes:

$$N_{h}^{*} < 9:Household\ at\ Energy\ Poverty\ Line$$

This means a household earning less than \$9 of income for every dollar
spent on secondary energy is considered to be in energy poverty by the
traditional energy burden accounting method. A Net Energy Return of 9 or
lower is equivalent to an energy burden of 10% or higher. While this
threshold is somewhat arbitrary and may not be suitable in all
situations, it provides a useful benchmark for comparing results to the
energy poverty literature.

### The LEAD Tool and temporal analysis

The U.S. Department of Energy’s Low-Income Energy Affordability Data
(LEAD) Tool (Ma et al. 2019) provides census tract-level estimates of
household energy characteristics based on American Community Survey
microdata. The tool uses iterative proportional fitting to allocate
households to census tracts while calibrating to utility-reported sales
and revenues.

Multiple vintages of LEAD Tool data have been released:

- **2018 Update**: Based on 2018 5-year ACS data, released July 2020
- **2022 Update**: Based on 2022 5-year ACS data, released August 2024

These vintages enable temporal analysis of energy burden trends, but
require careful handling of schema differences and income bracket
definitions.

### Package design philosophy

The package is designed around several key principles:

1.  **Proper aggregation**: Implements weighted mean aggregation using
    Net Energy Return, with household counts as weights
2.  **Temporal consistency**: Normalizes schema differences between LEAD
    Tool vintages to enable valid comparisons
3.  **Flexible workflows**: Supports both database and CSV-based data
    access with automatic fallback
4.  **Geographic flexibility**: Enables analysis from national level
    down to individual census tracts

## Methodology

### Data sources

The package provides access to three primary datasets for household
energy burden analysis:

#### LEAD Tool

The Low-Income Energy Affordability Data (LEAD) Tool (Ma et al. 2019)
portrays average income, electricity expenditures, gas expenditures, and
other fuel expenditures for cohorts of households segmented by location
(census tract, county, state) and household characteristics (ownership
status, building age, number of units, attachment status, primary
heating fuel).

The dataset is assembled using iterative proportional fitting (IPF), a
widely used spatial microsimulation method to allocate households to
census tracts while calibrating characteristics to known quantities. The
IPF algorithm processes cross-tabulations of household responses from
the American Community Survey (ACS) Public Use Microdata Samples,
scaling them to match aggregate annual values from utility sales and
revenues reported in Energy Information Administration forms 861
(electricity) and 176 (natural gas).

Multiple vintages are available:

- **2018 Update**: Based on 2016 5-year ACS data (2012-2016), released
  July 2020
- **2022 Update**: Based on 2018 5-year ACS data (2014-2018), released
  August 2024

#### REPLICA dataset

The Renewable Energy Potential of Low-Income Communities in America
(REPLICA) dataset (Sigrin and Mooney 2018) adds technical rooftop solar
potential and additional techno-economic variables including
demographics and electricity rates. The package can merge REPLICA data
with LEAD data to enrich analyses with utility type, locale
classification, and solar generation potential.

#### Schema normalization across vintages

A critical challenge in temporal analysis is handling schema differences
between LEAD Tool vintages. The package implements automatic
normalization through the following transformations:

**Income bracket aggregation**: The LEAD Tool provides income as a
fraction of Area Median Income (AMI) or Federal Poverty Level (FPL). For
AMI data, the package can aggregate detailed brackets into simplified
categories matching the REPLICA schema:

- 0-30% AMI: Very Low Income
- 30-80% AMI: Low-to-Moderate Income
- 80%+ AMI: Middle-to-High Income

For FPL data, the aggregation follows poverty line definitions:

- 0-100% FPL: In Poverty
- 100%+ FPL: Not In Poverty

**Building type simplification**: Housing units are classified as:

- 1 Unit: Single-Family

- 1 Unit: Multi-Family

- Other Unit: Excluded from analysis

These normalizations enable valid temporal comparisons despite
underlying schema evolution between vintages.

### Data processing

The package processes raw LEAD Tool data through several stages:

#### Energy burden indicator calculation

For each household cohort, the package calculates:

$$s = electricity + natural\ gas + other\ fuels$$

$$g = annual\ household\ income$$

From these base metrics, all energy burden indicators are derived using
the formulas presented in Section 1.1.

#### Weighted aggregation

The package implements proper weighted aggregation using household
counts as weights. For Net Energy Return:

``` r
calculate_weighted_metrics(
  data,
  group_columns = c("state", "income_bracket"),
  metric_name = "ner"
)
```

This function:

1.  Filters data to specified groups
2.  Calculates weighted means using household counts
3.  Computes poverty rates below specified thresholds
4.  Returns summary statistics including quantiles and standard
    deviations

The key insight is that Net Energy Return allows arithmetic weighted
means, while energy burden would require harmonic mean aggregation—a
distinction that significantly impacts the validity and interpretability
of aggregate statistics.

#### Data quality considerations

Iterative proportional fitting has limitations as an estimation
procedure. The relationship between constraint variables tends toward
the average of the initializing dataset, potentially depressing
variations among otherwise similar regions. This may explain the large
quantities of households estimated to have very low incomes. Validating
these estimated data would require randomized surveys along the
dimensions of interest.

Additionally, the “primary heating fuel” category derives from the ACS
question “Which fuel is used most for heating this house, apartment, or
mobile home?” The predictive power of this question for energy
expenditures is not fully understood and warrants caution in
interpretation.

Though REPLICA relies on a different LEAD vintage (2017) than recent
analyses (2019, 2022), the package still enables useful cross-dataset
analysis. However, inferring differences among annual estimates should
account for the standard error of the data (Ma et al. 2019). Rigorous
temporal analysis benefits from comparing identically-processed
vintages.

## Package architecture

The package is organized into several functional modules:

### Core functions

``` r
library(emburden)

# Energy metric calculations
energy_burden_func(gross_income, energy_spending)
ner_func(gross_income, energy_spending)  # Net Energy Return
eroi_func(gross_income, energy_spending)  # EROI
dear_func(gross_income, energy_spending)  # DEAR

# Statistical aggregation
calculate_weighted_metrics(
  graph_data,
  group_columns = "state",
  metric_name = "ner"
)
```

### Data loading functions

The package provides automatic data downloading and caching:

``` r
# Load census tract data (auto-downloads if not available)
nc_tracts <- load_census_tract_data(states = "NC")

# Load cohort data by income bracket
nc_ami <- load_cohort_data(
  dataset = "ami",
  states = "NC",
  vintage = "2022"
)

# Compare vintages
comparison <- compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "state"
)
```

## Analysis examples

The package’s primary contribution is enabling temporal analysis of
energy burden through proper schema normalization and aggregation. This
section demonstrates the package’s capabilities through progressively
detailed examples.

### Temporal comparison workflow

The
[`compare_energy_burden()`](https://ericscheier.github.io/emburden/reference/compare_energy_burden.md)
function provides the core temporal analysis functionality:

``` r
library(emburden)

# Compare North Carolina energy burden: 2018 vs 2022
nc_comparison <- compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "income_bracket"
)

# View formatted comparison table
print(nc_comparison)
```

The function automatically:

1.  Downloads both vintages if not cached locally
2.  Normalizes schema differences between vintages
3.  Performs proper $N_{h}$-based weighted aggregation
4.  Calculates energy burden for both periods
5.  Computes changes in percentage points

#### Understanding the output

The comparison object contains multiple metrics:

``` r
# Energy burden in 2018 and 2022
nc_comparison$neb_2018
nc_comparison$neb_2022

# Change in energy burden (percentage points)
nc_comparison$neb_change_pp

# Net Energy Return values
nc_comparison$ner_2018
nc_comparison$ner_2022

# Household counts
nc_comparison$households_2018
nc_comparison$households_2022
```

### Example 1: State-level temporal analysis

To examine overall state changes without grouping by demographic
characteristics:

``` r
# Overall state comparison
nc_state <- compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "none"
)

# Extract key findings
cat(sprintf(
  "North Carolina energy burden changed from %.1f%% (2018) to %.1f%% (2022)\n",
  nc_state$neb_2018 * 100,
  nc_state$neb_2022 * 100
))

cat(sprintf(
  "Change: %+.2f percentage points\n",
  nc_state$neb_change_pp * 100
))
```

### Example 2: Income bracket analysis

Disaggregating by income bracket reveals which populations experienced
the largest changes:

``` r
# Compare by income bracket
nc_income <- compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "income_bracket"
)

# Visualize changes
library(ggplot2)

ggplot(nc_income, aes(x = income_bracket, y = neb_change_pp * 100)) +
  geom_col(fill = "steelblue") +
  geom_hline(yintercept = 0, linetype = "dashed") +
  labs(
    title = "Change in Energy Burden by Income Bracket",
    subtitle = "North Carolina, 2018 to 2022",
    x = "Income Bracket (% of Area Median Income)",
    y = "Change in Energy Burden (percentage points)"
  ) +
  theme_minimal()
```

Typical findings show that very low-income households (0-30% AMI)
experience the highest energy burdens and are most vulnerable to changes
in energy costs or income levels.

### Example 3: Multi-state comparison

Comparing multiple states reveals regional patterns and policy impacts:

``` r
# Compare Southern states
southern_states <- compare_energy_burden(
  dataset = "ami",
  states = c("NC", "SC", "GA", "FL"),
  group_by = "state"
)

# Which states improved most?
southern_states %>%
  arrange(neb_change_pp) %>%
  select(state_abbr, neb_2018, neb_2022, neb_change_pp)

# Visualize state comparison
ggplot(southern_states, aes(x = reorder(state_abbr, neb_2022),
                             y = neb_2022 * 100)) +
  geom_col(fill = "darkgreen") +
  geom_point(aes(y = neb_2018 * 100), color = "red", size = 3) +
  labs(
    title = "Energy Burden by State: 2022 (bars) vs 2018 (points)",
    x = "State",
    y = "Energy Burden (%)"
  ) +
  theme_minimal()
```

### Example 4: Housing tenure analysis

Energy burden often varies significantly between renters and homeowners:

``` r
# Compare by housing tenure
nc_tenure <- compare_energy_burden(
  dataset = "ami",
  states = "NC",
  group_by = "housing_tenure"
)

# Calculate the renter-owner gap
gap_2018 <- nc_tenure$neb_2018[nc_tenure$housing_tenure == "RENTER"] -
            nc_tenure$neb_2018[nc_tenure$housing_tenure == "OWNER"]

gap_2022 <- nc_tenure$neb_2022[nc_tenure$housing_tenure == "RENTER"] -
            nc_tenure$neb_2022[nc_tenure$housing_tenure == "OWNER"]

cat(sprintf(
  "Renter-Owner energy burden gap: %.2f pp (2018) → %.2f pp (2022)\n",
  gap_2018 * 100,
  gap_2022 * 100
))
```

Renters typically face higher energy burdens due to split-incentive
problems where landlords make efficiency investment decisions but
tenants pay energy bills.

### Example 5: Federal Poverty Line analysis

For policy applications targeting households below the federal poverty
line:

``` r
# Use FPL dataset instead of AMI
nc_fpl <- compare_energy_burden(
  dataset = "fpl",
  states = "NC",
  group_by = "income_bracket"
)

# Compare poverty vs non-poverty households
nc_fpl %>%
  filter(income_bracket %in% c("Below Federal Poverty Line",
                                "Above Federal Poverty Line")) %>%
  select(income_bracket, neb_2018, neb_2022, neb_change_pp)
```

This analysis is particularly relevant for programs like the Low-Income
Home Energy Assistance Program (LIHEAP) which target households below
specific poverty thresholds.

### Example 6: Census tract-level analysis

For fine-grained spatial analysis, load tract-level data directly:

``` r
# Load 2022 census tract data
nc_tracts_2022 <- load_census_tract_data(
  states = "NC",
  vintage = "2022"
)

# Calculate county-level statistics
nc_counties <- calculate_weighted_metrics(
  nc_tracts_2022,
  group_columns = "county_name",
  metric_name = "ner"
)

# Identify counties with highest energy burden
nc_counties %>%
  mutate(energy_burden = 1 / (ner + 1)) %>%
  arrange(desc(energy_burden)) %>%
  head(10) %>%
  select(county_name, energy_burden, household_count)
```

Census tract data enables spatial analysis and mapping applications,
revealing urban-rural disparities and identifying communities in need of
targeted assistance.

## Discussion

### Policy implications

The ability to track energy burden changes over time has important
policy implications. Programs like LIHEAP (Low-Income Home Energy
Assistance Program) and WAP (Weatherization Assistance Program) target
households experiencing energy insecurity, but evaluating their
effectiveness requires robust temporal analysis.

The package enables researchers and policymakers to:

1.  **Track program impacts**: Compare energy burden before and after
    policy interventions
2.  **Identify vulnerable populations**: Disaggregate trends by income,
    tenure, and geography
3.  **Allocate resources effectively**: Target communities with
    worsening energy affordability
4.  **Benchmark across jurisdictions**: Compare state and local policy
    outcomes

#### Split-incentive and principal-agent problems

A persistent challenge in energy equity is the split-incentive problem:
landlords make energy efficiency investment decisions, but tenants pay
the energy bills. This misalignment of incentives leads to
underinvestment in efficiency improvements for rental properties.

The package’s ability to analyze energy burden by housing tenure reveals
the magnitude of this problem:

``` r
# Quantify the renter-owner gap
tenure_comparison <- compare_energy_burden(
  dataset = "ami",
  states = "all",  # National analysis
  group_by = "housing_tenure"
)

# Calculate disparity
renter_burden <- tenure_comparison$neb_2022[
  tenure_comparison$housing_tenure == "RENTER"
]
owner_burden <- tenure_comparison$neb_2022[
  tenure_comparison$housing_tenure == "OWNER"
]

disparity_ratio <- renter_burden / owner_burden
```

Addressing this gap requires policy interventions such as:

- On-bill financing programs
- Landlord incentive programs
- Energy efficiency standards for rental properties
- Community-scale renewable energy projects

### Data limitations and considerations

Users should be aware of several data limitations:

#### Iterative proportional fitting constraints

The LEAD Tool uses IPF to allocate households to census tracts, which
has important implications:

1.  **Regression toward the mean**: IPF tends to depress variations
    among similar regions
2.  **Estimation uncertainty**: Standard errors are substantial,
    especially for small cohorts
3.  **Temporal comparability**: Different ACS vintages may have
    methodological differences

#### Income measurement challenges

Household income as reported in the ACS has known limitations:

- **Underreporting**: Particularly for benefits and informal income
- **Timing**: Income is annual but energy costs vary seasonally
- **Household composition**: Per-capita income may be more relevant for
  some analyses

#### Energy expenditure estimation

The “primary heating fuel” categorization derives from a single ACS
question and may not fully capture:

- Mixed-fuel households
- Behavioral patterns
- Appliance efficiency variations
- Climate variations within states

Despite these limitations, the LEAD Tool represents the most
comprehensive spatial dataset available for energy burden analysis in
the United States.

### Future research directions

Several extensions would enhance the package’s capabilities:

#### Additional vintages

As DOE releases new LEAD Tool vintages (potentially 2024, 2026, etc.),
the package can incorporate them to enable longer-term trend analysis.
This would support:

- Multi-year trend identification
- Correlation with economic cycles
- Climate change impact assessment

#### Additional metrics

The package currently implements Net Energy Return, EROI, and DEAR.
Future versions could add:

- **Disposable income ratios**: Accounting for essential expenses beyond
  energy
- **Energy poverty depth**: How far below thresholds households fall
- **Vulnerability indices**: Combining burden with demographic risk
  factors

#### Spatial analysis enhancements

Geographic extensions could include:

- Integration with climate zone data
- Utility service territory analysis
- Transportation energy burden incorporation
- Built environment characteristics

#### Causal analysis tools

Methodological extensions for policy evaluation:

- Difference-in-differences estimation
- Synthetic control methods
- Regression discontinuity designs
- Propensity score matching

### Comparison with existing tools

Several tools exist for energy burden analysis, each with different
strengths:

- **LEAD Tool web interface**: Interactive but limited temporal
  comparison
- **State energy office tools**: Customized but not standardized across
  states
- **Academic datasets**: Rich but often one-time snapshots
- : Focused on temporal analysis with proper aggregation methodology

The package fills a gap by providing programmatic access to multiple
vintages with automated schema normalization, enabling reproducible
temporal analyses at scale.

## Conclusion

The package provides a robust framework for temporal analysis of
household energy burden using proper Net Energy Return methodology. By
automating data access, normalizing schema differences, and implementing
correct aggregation methods, the package enables researchers and
policymakers to track energy affordability trends across multiple
scales.

Key contributions include:

1.  **Mathematical foundations**: Proper Net Energy Return aggregation
    avoiding double-counting
2.  **Temporal consistency**: Automated schema normalization across LEAD
    Tool vintages
3.  **Flexible analysis**: Functions supporting national, state, county,
    and tract-level analysis
4.  **Policy relevance**: Direct support for energy assistance program
    evaluation

The package is available from GitHub at and is licensed under AGPL-3+.
Documentation, vignettes, and issue tracking are available through the
package website.

## References

Bednar, Dominic J, and Tony G Reames. 2020. “Recognition of and Response
to Energy Poverty in the United States.” *Nature Energy* 5 (6): 432–39.
<https://doi.org/10.1038/s41560-020-0582-0>.

Brandt, Adam R, Michael Dale, and Charles J Barnhart. 2013. “Calculating
Systems-Scale Energy Efficiency and Net Energy Returns: A Bottom-up
Matrix-Based Approach.” *Energy* 62: 235–47.
<https://doi.org/10.1016/j.energy.2013.09.054>.

Carbajales-Dale, Michael, Charles J Barnhart, Adam R Brandt, and Sally M
Benson. 2014. “Can We Better Understand How Nations Produce and Consume
Energy and Economic Resources? Integrating Approaches from Ecology,
Energy Analysis, and Economics.” *Energies* 7 (3): 1347–96.

Drehobl, Ariel, and Lauren Ross. 2016. “Lifting the High Energy Burden
in America’s Largest Cities: How Energy Efficiency Can Improve Low
Income and Underserved Communities.” American Council for an
Energy-Efficient Economy.

Hall, Charles AS, Jessica G Lambert, and Stephen B Balogh. 2011. “EROI
of Different Fuels and the Implications for Society.” *Energy Policy* 39
(10): 5938–52.

Ma, Ou, Jonathan Layke, Jeff Deason, Richard E Brown, and Alex Lekov.
2019. “Low-Income Energy Affordability Data (LEAD) Tool Methodology.”
LBNL-2001326. Lawrence Berkeley National Laboratory.

Ross, Lauren, Ariel Drehobl, and Brian Stickles. 2018. “How Energy
Efficiency Cuts Costs for Low-Income and Minority Households.” *American
Council for an Energy-Efficient Economy*.

Scheier, Eric, and Noah Kittner. 2022. “A Measurement Strategy to
Address Disparities Across Household Energy Burdens.” *Nature
Communications* 13 (1): 1717.
<https://doi.org/10.1038/s41467-021-27673-y>.

Sigrin, Benjamin, and Meghan Mooney. 2018. “The Rooftop Solar Technical
Potential of Low-to-Moderate Income Households in the United States
(REPLICA).” NREL/TP-6A20-70901. National Renewable Energy Laboratory.
