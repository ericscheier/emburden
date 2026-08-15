#!/usr/bin/env Rscript
# Broadcast county-year WONDER homicide rates into the tract-year panel.
# All tracts in a county share the same county-year homicide rate.
#
# Input:  data/wonder_violence_county_year_2018_2023.rds
#         data/tract_panel_enhanced_for_analysis.csv
# Output: data/tract_panel_enhanced_with_homicide.csv (extra columns:
#         wonder_homicide_rate, wonder_homicide_deaths, wonder_homicide_pop,
#         wonder_homicide_suppressed)

suppressPackageStartupMessages({
  library(data.table)
  library(readr)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"

hom <- readRDS(file.path(REPO, "data",
                         "wonder_violence_county_year_2018_2023.rds"))
setDT(hom)
cat(sprintf("Loaded homicide panel: %s rows, states = %d, counties = %d\n",
            format(nrow(hom), big.mark = ","),
            uniqueN(hom$state_fips), uniqueN(hom$county_fips)))

# Keep only the columns we need — homicide-specific + all_external if present
keep <- intersect(c("county_fips", "year",
                    "homicide_deaths", "homicide_population",
                    "homicide_rate_per_100k", "homicide_suppressed",
                    "all_external_deaths", "all_external_rate_per_100k"),
                  names(hom))
hom_slim <- hom[, ..keep]
# Rename to unambiguous wonder_ prefix
rename_map <- c(
  homicide_deaths = "wonder_homicide_deaths",
  homicide_population = "wonder_homicide_pop",
  homicide_rate_per_100k = "wonder_homicide_rate",
  homicide_suppressed = "wonder_homicide_suppressed",
  all_external_deaths = "wonder_all_external_deaths",
  all_external_rate_per_100k = "wonder_all_external_rate"
)
for (old in names(rename_map)) {
  if (old %in% names(hom_slim)) setnames(hom_slim, old, rename_map[[old]])
}

cat("Reading tract panel ...\n")
panel <- fread(file.path(REPO, "data",
                         "tract_panel_enhanced_for_analysis.csv"),
               showProgress = FALSE)
cat(sprintf("  %s tract-years\n", format(nrow(panel), big.mark = ",")))

# Coerce county_fips to character on both sides (panel had integer; hom has char)
if ("county_fips" %in% names(panel)) {
  panel[, county_fips := formatC(as.integer(county_fips), width = 5, flag = "0")]
} else {
  panel[, county_fips := substr(as.character(geoid), 1, 5)]
}
hom_slim[, county_fips := as.character(county_fips)]

# Left join
before <- nrow(panel)
merged <- merge(panel, hom_slim,
                by = c("county_fips", "year"), all.x = TRUE)
after  <- nrow(merged)
stopifnot(before == after)

# Report merge quality
matched <- sum(!is.na(merged$wonder_homicide_rate))
cat(sprintf("  Homicide matched: %s tract-years (%.1f%%)\n",
            format(matched, big.mark = ","), 100 * matched / after))

fwrite(merged, file.path(REPO, "data",
                         "tract_panel_enhanced_with_homicide.csv"))
cat(sprintf("Wrote: data/tract_panel_enhanced_with_homicide.csv (%s cols)\n",
            ncol(merged)))
