#!/usr/bin/env Rscript
# Build cumulative CA SGIP residential-storage rollup by county-year
# (2014, 2018, 2022 waves matching the panel).
# Uses SGIP project-level `county` column directly (97% populated) + tigris
# fips_codes for the 3-digit county code lookup. Bypasses the ZCTA
# crosswalk which is either broken (Census natl file has blank ZCTA cols)
# or WAF-blocked (HUD USPS).

suppressPackageStartupMessages({
  library(dplyr); library(data.table); library(tigris)
  devtools::load_all("/home/ess/Documents/apps/emburdendata", quiet = TRUE)
})

REPO <- "/home/ess/Documents/apps/net_energy_equity"
DATA <- file.path(REPO, "data")

# ---- 1. Load SGIP projects ---------------------------------------------
message("Loading CA SGIP projects...")
prj <- as.data.table(load_ca_sgip_projects(complete_only = FALSE, verbose = FALSE))
message(sprintf("Loaded %s SGIP records", format(nrow(prj), big.mark=",")))

# Filter to storage tech
bat <- prj[grepl("Electrochemical Storage|Mechanical Storage", technology_type,
                 ignore.case = TRUE)]

# Effective vintage year: prefer installed_date (interconnection), fallback to program_year
bat[, vintage_year := suppressWarnings(as.integer(format(installed_date, "%Y")))]
bat[is.na(vintage_year), vintage_year := suppressWarnings(as.integer(program_year))]

bat[, is_residential := grepl("Residential|Single Family|Multifamily",
                              sector, ignore.case = TRUE)]
bat[, is_equity := grepl("Equity|Small Residential|San Joaquin",
                         budget_category, ignore.case = TRUE)]

# ---- 2. County FIPS lookup ---------------------------------------------
data("fips_codes", package = "tigris", envir = environment())
ca_fips <- as.data.table(fips_codes[fips_codes$state_code == "06", ])
ca_fips[, county_key := tolower(gsub("[[:punct:]]| County| Parish", "", county))]
ca_fips[, county_fips := paste0(state_code, county_code)]
county_lookup <- ca_fips[, .(county_key, county_fips)]

bat[, county_key := tolower(gsub("[[:punct:]]| County| Parish", "",
                                 as.character(county)))]
bat_fips <- county_lookup[bat, on = "county_key"]
bat_fips <- bat_fips[!is.na(county_fips)]

# County name coverage
cov_pct <- 100 * nrow(bat_fips) / nrow(bat)
message(sprintf("County-FIPS matched: %s of %s (%.1f%%)",
                format(nrow(bat_fips), big.mark=","),
                format(nrow(bat), big.mark=","),
                cov_pct))

# ---- 3. Build cumulative county-year rollup -----------------------------
build_county_year <- function(cutoff_year) {
  sub <- bat_fips[!is.na(vintage_year) & vintage_year <= cutoff_year]
  if (nrow(sub) == 0) return(NULL)
  cy <- sub[, .(
    sgip_battery_all_count   = .N,
    sgip_battery_all_kwh     = sum(installed_kwh, na.rm = TRUE),
    sgip_residential_count   = sum(is_residential, na.rm = TRUE),
    sgip_residential_kwh     = sum(installed_kwh[is_residential], na.rm = TRUE),
    sgip_equity_count        = sum(is_equity, na.rm = TRUE),
    sgip_equity_kwh          = sum(installed_kwh[is_equity], na.rm = TRUE)
  ), by = .(county_fips)]
  cy[, year := as.integer(cutoff_year)]
  cy
}

# Build for all three panel waves
cy_2014 <- build_county_year(2014)
cy_2018 <- build_county_year(2018)
cy_2022 <- build_county_year(2022)
all_cy  <- rbind(cy_2014, cy_2018, cy_2022, fill = TRUE)
setorder(all_cy, county_fips, year)

out_path <- file.path(DATA, "county_year_ca_sgip.rds")
saveRDS(as.data.frame(all_cy), out_path)
message(sprintf("\nWrote %s (%d rows, %d unique CA counties)",
                out_path, nrow(all_cy), uniqueN(all_cy$county_fips)))

# Summary
cat("\nCA SGIP storage cumulative by wave year:\n")
print(all_cy[, .(counties = uniqueN(county_fips),
                 total_projects = sum(sgip_battery_all_count),
                 total_kwh_MWh = round(sum(sgip_battery_all_kwh)/1000, 0),
                 residential_pct = round(100*sum(sgip_residential_count)/sum(sgip_battery_all_count), 1),
                 equity_pct = round(100*sum(sgip_equity_count)/sum(sgip_battery_all_count), 1)),
             by = year])

cat("\nTop 10 CA counties by 2022 residential SGIP kWh:\n")
top10 <- all_cy[year == 2022][order(-sgip_residential_kwh)][1:10]
top10[, county_name := ca_fips$county[match(top10$county_fips, ca_fips$county_fips)]]
print(top10[, .(county_fips, county_name,
                sgip_residential_count, sgip_residential_kwh = round(sgip_residential_kwh))])
