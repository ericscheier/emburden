#!/usr/bin/env Rscript
# Build county-year EIA-860 utility-scale battery storage (BESS) panel
# with ownership-class split (IOU vs merchant vs muni vs coop etc).
# Uses the new emburdendata::load_eia860_owners() to classify owners via
# Schedule 1 (utility) entity_type + owner-name pattern fallback.

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(data.table); library(tigris)
  devtools::load_all("/home/ess/Documents/apps/emburdendata", quiet = TRUE)
})

CACHE <- path.expand("~/.cache/emburdendata/eia860")
DATA  <- "/home/ess/Documents/apps/net_energy_equity/data"

parse_storage_owners <- function(yr) {
  bess_f <- Sys.glob(sprintf("%s/eia860_%d_raw/3_4_Energy_Storage_Y%d.xlsx",
                             CACHE, yr, yr))
  if (length(bess_f) == 0) {
    warning(sprintf("EIA-860 %d storage sheet missing", yr)); return(NULL)
  }

  sheets <- excel_sheets(bess_f)
  op_sheet <- grep("^Operable", sheets, value = TRUE)[1]
  if (is.na(op_sheet)) op_sheet <- 1
  bess <- suppressMessages(read_excel(bess_f, sheet = op_sheet, skip = 1))
  names(bess) <- trimws(gsub("[\n\r]+", " ", names(bess)))

  bess_slim <- bess %>%
    transmute(
      plant_id  = suppressWarnings(as.integer(`Plant Code`)),
      state     = as.character(`State`),
      county    = as.character(`County`),
      status    = as.character(`Status`),
      cap_mw    = suppressWarnings(as.numeric(`Nameplate Capacity (MW)`)),
      cap_mwh   = suppressWarnings(as.numeric(`Nameplate Energy Capacity (MWh)`))) %>%
    filter(!is.na(plant_id))

  owners <- tryCatch(load_eia860_owners(yr), error = function(e) {
    warning(sprintf("owner load failed for %d: %s", yr, conditionMessage(e)))
    NULL
  })
  if (is.null(owners) || nrow(owners) == 0) return(NULL)
  owners <- owners %>% mutate(plant_id = suppressWarnings(as.integer(plant_id)))

  # Aggregate owner shares to plant-level (average across generators
  # within a plant; for storage-only plants this is exact, for mixed
  # plants this is an approximation)
  plant_own <- owners %>%
    group_by(plant_id, owner_class) %>%
    summarise(share = mean(as.numeric(percent_owned)/100, na.rm = TRUE),
              .groups = "drop") %>%
    mutate(share = ifelse(is.na(share) | !is.finite(share), NA_real_, share)) %>%
    group_by(plant_id) %>%
    # Normalize shares to sum to 1 within plant (some rows have NA percent_owned)
    mutate(total = sum(share, na.rm = TRUE),
           share_norm = ifelse(total > 0, share/total, NA_real_)) %>%
    ungroup() %>%
    select(plant_id, owner_class, share = share_norm)

  # Join owners to BESS; if plant has no owner record, credit as "unknown"
  bess_o <- bess_slim %>%
    left_join(plant_own, by = "plant_id", relationship = "many-to-many") %>%
    mutate(owner_class = ifelse(is.na(owner_class), "unknown", owner_class),
           share = ifelse(is.na(share), 1, share),
           cap_mw_share  = cap_mw * share,
           cap_mwh_share = cap_mwh * share)

  # County FIPS lookup via tigris
  data("fips_codes", package = "tigris", envir = environment())
  fips_lookup <- fips_codes %>%
    mutate(county_key = tolower(gsub("[[:punct:]]| County| Parish| Borough| Census Area| Municipality| City and Borough", "", county))) %>%
    transmute(state_abbr = state, county_key,
              state_fips_2 = state_code, county_fips_3 = county_code)

  bess_o %>%
    mutate(
      state_abbr = state,
      county_key = tolower(gsub("[[:punct:]]| County| Parish| Borough| Census Area| Municipality| City and Borough", "", county))
    ) %>%
    left_join(fips_lookup, by = c("state_abbr", "county_key")) %>%
    mutate(
      year = yr,
      county_fips = ifelse(is.na(state_fips_2) | is.na(county_fips_3), NA_character_,
                           paste0(state_fips_2, county_fips_3)),
      operable = grepl("^OP", status)
    ) %>%
    filter(!is.na(county_fips))
}

all_years <- lapply(2019:2022, parse_storage_owners)
all_dt <- as.data.table(bind_rows(all_years))
cat(sprintf("BESS-owner rows loaded: %s (2019-2022)\n",
            format(nrow(all_dt), big.mark=",")))

# County-year × owner_class pivot
cy_by_class <- all_dt[, .(
  bess_mw_share  = sum(cap_mw_share,  na.rm = TRUE),
  bess_mwh_share = sum(cap_mwh_share, na.rm = TRUE)
), by = .(county_fips, year, owner_class)]

cy_wide <- dcast(cy_by_class, county_fips + year ~ owner_class,
                 value.var = "bess_mw_share", fill = 0)
setnames(cy_wide,
         setdiff(names(cy_wide), c("county_fips", "year")),
         paste0("bess_mw_", setdiff(names(cy_wide), c("county_fips", "year"))))
cy_wide_e <- dcast(cy_by_class, county_fips + year ~ owner_class,
                   value.var = "bess_mwh_share", fill = 0)
setnames(cy_wide_e,
         setdiff(names(cy_wide_e), c("county_fips", "year")),
         paste0("bess_mwh_", setdiff(names(cy_wide_e), c("county_fips", "year"))))

cy <- merge(cy_wide, cy_wide_e, by = c("county_fips", "year"))
setorder(cy, county_fips, year)

# Derived metrics
mw_cols <- grep("^bess_mw_", names(cy), value = TRUE)
cy[, bess_mw_total := rowSums(.SD, na.rm = TRUE), .SDcols = mw_cols]
for (need_col in c("bess_mw_IOU", "bess_mw_IPP-non-CHP", "bess_mw_IPP-CHP",
                   "bess_mw_muni", "bess_mw_coop", "bess_mw_federal",
                   "bess_mw_state", "bess_mw_unknown")) {
  if (!need_col %in% names(cy)) cy[[need_col]] <- 0
}
cy[, bess_iou_pct := ifelse(bess_mw_total > 0,
                            bess_mw_IOU / bess_mw_total, NA_real_)]
cy[, bess_merchant_pct := ifelse(bess_mw_total > 0,
                                 (cy[["bess_mw_IPP-non-CHP"]] +
                                  cy[["bess_mw_IPP-CHP"]]) / bess_mw_total,
                                 NA_real_)]

saveRDS(as.data.frame(cy),
        file.path(DATA, "county_year_eia860_storage_by_owner.rds"))
cat(sprintf("\nWrote data/county_year_eia860_storage_by_owner.rds (%s rows, %d counties)\n",
            format(nrow(cy), big.mark=","), uniqueN(cy$county_fips)))

cat("\nBESS MW by owner class × year:\n")
print(all_dt[, .(mw_share = sum(cap_mw_share, na.rm=TRUE),
                 n_plant_owner = .N),
             by = .(year, owner_class)][order(year, -mw_share)])
