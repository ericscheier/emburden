# Poster Infrastructure Status

## Overview

Organized poster infrastructure for academic conference presentations based on the Net Energy Burden research. Supports parallel 2018 and 2022 data versions.

## Current Status

### Compilation Issues (In Progress)
The 2022 paper compilation has made good progress:
- ✅ Fixed: Households column missing error (chunk 36)
- ✅ Fixed: state_abbr column duplication (chunk 38 inset-map)
- ⏳ Current: Basemap parameter error at chunk 38
  - Error: `get_stamenmap` receiving invalid maptype argument
  - Location: net_energy_equity_2022.Rmd:671-755 [inset-map]

### Poster Organization (New)
Created organized directory structure:
```
research/posters/
├── 2018/          # 2014-2018 ACS data posters
├── 2022/          # 2018-2022 ACS data posters
├── shared/        # Shared templates and assets
└── README.md      # Documentation
```

## Next Steps

### Paper Compilation
1. Fix `include_basemap` parameter in inset-map chunk
   - Issue: choropleth_map passes basemap to ggmap::get_stamenmap incorrectly
   - Solution: Check figures.R choropleth_map function for basemap handling

### Poster Development
1. Create data generation scripts:
   - `research/posters/2018/generate_poster_data_2018.R`
   - `research/posters/2022/generate_poster_data_2022.R`
2. Create poster templates:
   - `research/posters/2018/poster_2018.Rmd`
   - `research/posters/2022/poster_2022.Rmd`
3. Move existing poster files to organized structure
4. Generate both versions and verify outputs

## Data Sources

### 2018 Version
- ACS: 2014-2018 5-year estimates
- LEAD Data: 2018 version
- Currently used by: MES_2022_poster.Rmd (misleading name)

### 2022 Version
- ACS: 2018-2022 5-year estimates
- LEAD Data: 2022 version
- Parallel to: net_energy_equity_2022.Rmd paper

## Key Files

- Paper (2022): `net_energy_equity_2022.Rmd`
- Paper (2018): `net_energy_equity.Rmd`
- Existing poster: `MES_2022_poster.Rmd` (uses 2018 data)
- Data loader: `MarketFigures.R` (2018 data, line 21: `acs_version=2018`)
