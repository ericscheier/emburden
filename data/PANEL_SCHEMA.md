# Tract Panel Schema — `tract_panel_enhanced_with_ders.csv`

**Rows:** 295,134 tract-years across 72,760 unique census tracts
**Years:** 2014, 2018, 2022 (matched to outage waves)
**Grain:** US census tract × year (state = 01..78 including territories)
**Producer:** `analysis/merge_ders_into_tract_panel.R`

## Upstream dependencies

The enriched panel is a strict join of six sources on `(geoid, year)`
and `(county_fips, year)`:

| Source | Path | Producer |
|---|---|---|
| Base homicide panel | `data/tract_panel_enhanced_with_homicide.csv` | `analysis/merge_homicide_into_tract_panel.R` |
| DER tract panel | `~/.cache/emburdender/der_panel_tract_2009_2024.rds` | `emburdender::build_der_panel(geography="tract")` |
| Utility BESS (base) | `data/county_year_eia860_storage.rds` | `analysis/build_county_year_eia860_storage.R` |
| Utility BESS by owner | `data/county_year_eia860_storage_by_owner.rds` | `analysis/build_county_year_eia860_storage_by_owner.R` |
| Residential storage (audit) | `data/tract_year_residential_storage.rds` | `analysis/build_tract_year_residential_storage.R` |

## Column families

Column families are listed grouped by data provenance. Only new families
added by the DER merge are documented in full; the base homicide panel
columns (`avg_energy_burden.x`, `extreme_heat_days`, `wonder_homicide_rate`,
`treated_*`, etc.) inherit their documentation from the base panel.

### RESIDENTIAL STORAGE — LBNL Tracking-the-Sun (DER panel)

| Column | Unit | Source | Coverage | Caveats |
|---|---|---|---|---|
| `res_storage_count` | count | LBNL TTS via DER panel | 2009-2024 | Cumulative through year Y |
| `res_storage_kwh` | kWh | LBNL TTS via DER panel | 2009-2024 | Clipped ≥0. DER-panel path uses ZCTA→tract area-weighting so tract-summed totals are ~10x lower than direct LBNL TTS tract rollup (see `lbnl_audit_*`). |

**Bug fixed 2026-08-29**: LBNL TTS `-1` sentinels in the `storage_kwh` column
were formerly summed producing large negative aggregate values in
`.aggregate_tts_to_tract()`. Fix: clip to `pmax(., 0)` before summing and
emit a `storage_paired_kwh_missing_count` companion column. The DER panel
builder path (`emburdender::build_der_panel()`) was independently correct.

### UTILITY-SCALE BESS (base) — EIA-860 Schedule 3.4

| Column | Unit | Source | Coverage | Caveats |
|---|---|---|---|---|
| `bess_plant_count` | count | EIA-860 3_4_Energy_Storage | 2019-2022 | Broadcasted 2019→2018-wave, 2022→2022-wave; 2014-wave = 0 |
| `bess_capacity_mw` | MW | EIA-860 | 2019-2022 | Nameplate MW |
| `bess_capacity_mwh` | MWh | EIA-860 | 2019-2022 | Nameplate energy MWh |
| `bess_operating_mw` | MW | EIA-860 | 2019-2022 | Filtered `status == "OP*"` |
| `bess_operating_mwh` | MWh | EIA-860 | 2019-2022 | Filtered operable |
| `bess_any_storage` | 0/1 | EIA-860 | 2019-2022 | Indicator |

### UTILITY BESS BY OWNERSHIP (NEW — Wave B1) — EIA-860 Schedule 4

Owner-share-weighted MW/MWh split by owner class. Owner class derives
from EIA-860 Schedule 1 (`entity_type`) joined via `owner_id`;
falls back to `owner_name` pattern-match for corporate LLC owners not
in Schedule 1.

| Column | Unit | Source | Caveats |
|---|---|---|---|
| `bess_mw_IOU` | MW | EIA-860 Sch 4 + Sch 1 | Investor-owned utility share |
| `bess_mw_IPP-non-CHP` | MW | EIA-860 | Merchant IPP |
| `bess_mw_IPP-CHP` | MW | EIA-860 | Merchant IPP w/ CHP |
| `bess_mw_muni` | MW | EIA-860 | Municipal utility |
| `bess_mw_coop` | MW | EIA-860 | Rural cooperative |
| `bess_mw_federal` | MW | EIA-860 | Federal (TVA, BPA, USACE) |
| `bess_mw_state` | MW | EIA-860 | State (NYPA, etc.) |
| `bess_mw_political_subdivision` | MW | EIA-860 | Irrigation districts |
| `bess_mw_unknown` | MW | EIA-860 | Storage-only plants not in Sch 4 |
| `bess_mwh_*` | MWh | EIA-860 | Same split for energy MWh |
| `bess_iou_pct` | fraction | derived | `bess_mw_IOU / bess_mw_total` |
| `bess_merchant_pct` | fraction | derived | `(IPP-non-CHP + IPP-CHP) / total` |

**Coverage note**: EIA-860 Schedule 4 only records ownership arrangements
where multiple owners exist. Storage-only plants with single-owner
structures often produce zero Schedule 4 rows, so ~85% of 2022 US BESS
MW appear in `bess_mw_unknown`. The IOU/merchant split is
high-confidence but limited to the multi-owner subset.

### NET METERING & VIRTUAL NM — EIA-861 (DER panel)

| Column | Unit | Coverage |
|---|---|---|
| `nem_number_of_systems` | count | 2013-2024 |
| `nem_capacity_kw` | kW | 2013-2024 |
| `nem_storage_installations` | count | 2018-2024 |
| `nem_storage_capacity_mw` | MW | 2018-2024 |
| `nem_virtual_capacity_mw` | MW | 2020-2024 |
| `nem_virtual_customers` | count | 2020-2024 |

### DISTRIBUTED GENERATION — EIA-861 (DER panel)

| Column | Unit | Coverage |
|---|---|---|
| `dg_system_count` | count | 2013-2024 |
| `dg_capacity_kw` | kW | 2013-2024 |
| `dg_storage_capacity_kw` | kW | 2018-2024 |
| `dg_pv_capacity_kw` | kW | 2013-2024 |

### COMMUNITY SOLAR — NCSL / SEIA (DER panel)

| Column | Unit | Coverage |
|---|---|---|
| `cs_total_projects` | count | 2010-2024 |
| `cs_total_capacity_mw` | MW | 2010-2024 |
| `cs_lmi_projects` | count | 2010-2024 |

### USPVDB (utility PV) — USGS (DER panel)

| Column | Unit | Coverage |
|---|---|---|
| `uspvdb_cumulative_plants` | count | 2004-2023 |
| `uspvdb_cumulative_mw_dc` | MW-DC | 2004-2023 |

### DYNAMIC PRICING — EIA-861 (DER panel)

| Column | Unit | Coverage |
|---|---|---|
| `dp_has_tou`, `dp_has_rtp`, `dp_has_vpp`, `dp_has_cpp`, `dp_has_cpr` | 0/1 | 2013-2024 |
| `dp_tou_res`, `dp_rtp_res`, `dp_vpp_res`, `dp_cpp_res`, `dp_cpr_res` | count | 2013-2024 |

### CDC HEAT & HEALTH INDEX (Wave L2) — Harvard Dataverse mirror (`emburdendata::aggregate_cdc_hhi_to_county`)

Source: Harvard Dataverse DOI `10.7910/DVN/IIGITP` (file: HHI_Data.zip →
HHI Data 2024 United States.xlsx). ZCTA5-level; aggregated to county via
`tigris::zctas(2020)` ∩ `tigris::counties(2020)` area × POP weighting.

| Column | Unit | Coverage | Caveats |
|---|---|---|---|
| `hhi_overall_rank` | percentile [0,1] | static 2024 | Composite of the 4 sub-indices |
| `hhi_heat_burden_rank` | percentile [0,1] | static 2024 | Historical Heat & Health Burden (prior heat mortality) |
| `hhi_sensitivity_rank` | percentile [0,1] | static 2024 | Chronic-condition share (CHD/obesity/diabetes/COPD/asthma/mental) |
| `hhi_nbe_rank` | percentile [0,1] | static 2024 | Natural & Built Environment (imperviousness, tree cover, PM2.5) |
| `hhi_sociodem_rank` | percentile [0,1] | static 2024 | Sociodemographic (poverty, uninsured, no-HS, isolation, ELP) |

**Time-invariance**: HHI is single-vintage (2024). Broadcast across
2014/2018/2022 waves on `county_fips` only — reasonable for structural
heat vulnerability, but not for time-varying interventions.

**Coverage**: 3,108 counties across 49 states (excludes some
territories). CDC EPHT REST API `getCoreHolder` returns 400 for HHI
measure IDs 1504–1508; the Harvard Dataverse mirror is functionally
identical to the CDC-published bulk workbook and is the only
programmatically-accessible source (CDC's `apihelp` page 404s and the
`downloadhhi` endpoint requires a token no longer distributed).

### CALIFORNIA SGIP (Wave L) — `emburdendata::aggregate_ca_sgip_to_county`

Source: SGIP Weekly Statewide Report (selfgenca.com), 106,432 records
2001–present. Filtered to storage tech (Electrochemical + Mechanical
Storage), rolled up cumulative through wave year via SGIP-native
`county` column + `tigris::fips_codes` FIPS lookup (97% match rate).

| Column | Unit | Coverage | Caveats |
|---|---|---|---|
| `sgip_battery_all_count` | count | CA-only | All-sector cumulative through wave year |
| `sgip_battery_all_kwh` | kWh | CA-only | All-sector cumulative energy capacity |
| `sgip_residential_count` | count | CA-only | Sector = Residential / Single Family / Multifamily |
| `sgip_residential_kwh` | kWh | CA-only | Same, energy capacity |
| `sgip_equity_count` | count | CA-only | Budget cat = Equity / ERI / Small Residential / San Joaquin |
| `sgip_equity_kwh` | kWh | CA-only | Same, energy capacity |

**CA-only note**: non-CA counties have all `sgip_*` columns
zero-filled (0 = "no SGIP program in this state", not missing). The
FE-DiD moderator uses within-CA variation only.

**Filter gotcha**: to subset the panel to CA rows, filter on
`state_abbr == "CA"` — NOT `state_fips == "06"`. The panel writes
`state_fips` as `"6"` (leading zero stripped by CSV coerce), so the
string-literal `"06"` filter returns zero rows.

### AUDIT COLUMNS — `lbnl_audit_*`

Direct LBNL TTS tract rollup (not routed through ZCTA→tract crosswalk),
kept for verification against the DER-panel LBNL columns.

| Column | Notes |
|---|---|
| `lbnl_audit_res_solar_count` | Direct LBNL TTS solar system count |
| `lbnl_audit_res_solar_capacity_kw` | Direct LBNL TTS solar kW |
| `lbnl_audit_res_third_party_owned` | TPO count from direct rollup |
| `lbnl_audit_res_storage_penetration` | count / lbnl_solar_count |
| `lbnl_audit_res_storage_any` | 0/1 indicator |

## Zero-fill contract

Columns where "absence = 0" (not "missing"): all BESS/storage columns,
community solar, USPVDB, dynamic pricing. NA on merge is set to 0 so
that FE-DiD moderators do not drop the zero-DER tracts (which are the
counterfactual for the DER effect).

Columns where NA remains NA: base homicide panel columns, DER penetration
ratios (would divide by zero).

## Extending the panel

To add a new moderator:

1. If county-year: broadcast to tract-year in a new
   `data/county_year_<source>.rds` and merge inside
   `analysis/merge_ders_into_tract_panel.R`.
2. If tract-year: emit as new `data/tract_year_<source>.rds` and merge
   into the same script.
3. Add zero-fill entry to `zero_fill_cols` inside the merger if
   applicable.
4. Add row(s) to this schema doc.
5. Optionally add to `STORAGE_MODS` / `OTHER_DER_MODS` / `COMPARE_MODS`
   in `analysis/wave_outage_homicide_mitigation_full_ders.R` for it to
   appear in the mitigation sweep.
