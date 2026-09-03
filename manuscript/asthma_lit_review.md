# Automated Literature Review — asthma × emburden-ecosystem exposures

**Retrieved**: 2026-09-02  |  **Corpus size**: 116 abstracts (113 unique PMIDs)

**Source**: PubMed / NCBI E-utilities via `analysis/lit_review/pubmed_client.R`.

**Classification**: each abstract classified via Claude subagent on 5 dimensions
(relevance ∈ [0,1], triad_arm, study_type, population_scale, one-sentence bottom_line).
See `data/lit/asthma_triad_classified.rds`.

## 1. Query provenance

| Slug | Raw query | PMIDs | Median relevance |
|---|---|---|---|
| `outage` | `(asthma[MeSH]) AND ("power outage"[tiab] OR blackout*[tiab] OR "grid failure"[tiab]) AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]` | 1 | 1 |
| `air_quality` | `(asthma[MeSH]) AND ("PM2.5"[tiab] OR ozone[tiab] OR "air quality"[tiab]) AND ("census tract"[tiab] OR "environmental justice"[tiab] OR disparit*[tiab]) AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]` | 40 | 0.5 |
| `wildfire_smoke` | `(asthma[MeSH]) AND ("wildfire"[tiab] OR "smoke event"[tiab] OR "wildland fire"[tiab]) AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]` | 49 | 0.6 |
| `filtration_hepa` | `(asthma[MeSH]) AND ("air filtration"[tiab] OR HEPA[tiab] OR "portable air cleaner"[tiab]) AND (randomized[tiab] OR trial[tiab] OR intervention[tiab]) AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]` | 23 | 0.75 |
| `heat` | `(asthma[MeSH]) AND ("heat wave"[tiab] OR "extreme heat"[tiab]) AND (vulnerab*[tiab] OR sensitiv*[tiab]) AND ("2015"[PDAT] : "2026"[PDAT]) AND English[LA]` | 3 | 0.9 |

## 2. Ecosystem data plumbing vs. literature coverage

| Triad arm | Papers | Top study types | Ecosystem data status |
|---|---|---|---|
| `outage` | 2 | quasi_experimental (2) | ✅ 41 FEMA events, PSPS, EAGLE-I customer-hours — full analysis in Wave-L outage-homicide REPORT |
| `wildfire_smoke` | 47 | time_series (10), quasi_experimental (9), review_meta (9) | 🟡 NOAA HMS loader exists but county-day cache incomplete — see REPORT §11 Wave-2 followup |
| `air_quality` | 37 | cross_sectional (14), review_meta (8), cohort_observational (7) | ✅ EPHT PM2.5 + ozone county-year cached 2001–2020, EPA AQS daily loader available |
| `heat` | 3 | time_series (2), review_meta (1) | ✅ CDC EPHT extreme-heat-days county-year + treated_heat_wave binary built in Wave-asthma B4 |
| `filtration_hepa` | 27 | rct (17), other (4), review_meta (4) | ❌ No US-national HEPA/portable-air-cleaner uptake loader in fleet — priority Wave-2 build |

## 3.1 Top-relevance abstracts — outage (2 shown of 2)

| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |
|---|---:|---:|---|---|---|---|
| [41979329](https://pubmed.ncbi.nlm.nih.gov/41979329/) | 1.00 | 2026 | Epidemiology (Cambridge, Mass.) | quasi_experimental | neighborhood | NYC power outages associated with elevated asthma ED visits, especially among NYCHA children during summer (OR 2.23 lag 0-1). |
| [33583411](https://pubmed.ncbi.nlm.nih.gov/33583411/) | 0.80 | 2021 | Environmental health : a global access s | quasi_experimental | household | Modeling: energy-efficiency retrofits with mechanical ventilation save >$200/yr/child asthma costs; retrofits without ventilation raise costs. |

## 3.2 Top-relevance abstracts — wildfire_smoke (15 shown of 47)

| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |
|---|---:|---:|---|---|---|---|
| [42414291](https://pubmed.ncbi.nlm.nih.gov/42414291/) | 1.00 | 2026 | Nature communications | quasi_experimental | national | Brazil 2000-19: 1 ug/m3 wildfire PM2.5 raised asthma hospital cost 1.6% and length of stay 1.7% across 184M admissions. |
| [41720420](https://pubmed.ncbi.nlm.nih.gov/41720420/) | 1.00 | 2026 | American journal of obstetrics and gynec | cohort_observational | individual | In pregnant asthmatic Australians, >=10 days of wildfire smoke raised low birthweight OR 4.2, preterm birth OR 2.8, NICU admit OR 5.0. |
| [40480103](https://pubmed.ncbi.nlm.nih.gov/40480103/) | 1.00 | 2025 | Environment international | time_series | neighborhood | Reno 2012-19: 10 ug/m3 wildfire PM2.5 raised asthma ED/urgent-care visits 4-7%, larger effects from high-intensity forest fire smoke. |
| [40324806](https://pubmed.ncbi.nlm.nih.gov/40324806/) | 1.00 | 2025 | CMAJ : Canadian Medical Association jour | quasi_experimental | state | Ontario June 2023 wildfire smoke episode raised asthma-related ED visits 23.6% at lag 1 day, with sustained adult surge. |
| [37722035](https://pubmed.ncbi.nlm.nih.gov/37722035/) | 1.00 | 2023 | Proceedings of the National Academy of S | quasi_experimental | state | California 2006-17: wildfire smoke raised asthma/COPD/cough ED visits 30-110% in week after extreme smoke days. |
| [37616233](https://pubmed.ncbi.nlm.nih.gov/37616233/) | 1.00 | 2023 | MMWR. Morbidity and mortality weekly rep | time_series | national | US April-Aug 2023: Canadian wildfire smoke days raised asthma-related ED visits 17% overall, larger in age 5-64. |
| [36767304](https://pubmed.ncbi.nlm.nih.gov/36767304/) | 1.00 | 2023 | International journal of environmental r | cohort_observational | state | Calgary 2010-21: wildfire smoke days raised pediatric asthma exacerbations 13% (IRR 1.13) versus baseline. |
| [32854703](https://pubmed.ncbi.nlm.nih.gov/32854703/) | 1.00 | 2020 | Environmental health : a global access s | time_series | state | Reno 2013-18: wildfire smoke amplified asthma-visit association with 5 ug/m3 PM2.5 by ~6%. |
| [32051501](https://pubmed.ncbi.nlm.nih.gov/32051501/) | 1.00 | 2020 | Journal of exposure science & environmen | quasi_experimental | state | Oregon 2013: 10 ug/m3 wildfire PM2.5 raised asthma ED visits 8.9%, office visits 5% and rescue-inhaler fills 7.7%. |
| [41899691](https://pubmed.ncbi.nlm.nih.gov/41899691/) | 0.90 | 2026 | International journal of environmental r | cohort_observational | individual | Early-gestation wildfire PM2.5 exposure associated with altered infant tidal flows and 36% higher odds of asthma at age 6. |
| [41372919](https://pubmed.ncbi.nlm.nih.gov/41372919/) | 0.90 | 2025 | Environmental health : a global access s | quasi_experimental | neighborhood | Vermont/upstate NY: pediatric asthma control was worse in the smoke-affected summer 2023 versus 2022, but ZIP-code PM2.5 not consistently linked. |
| [38038861](https://pubmed.ncbi.nlm.nih.gov/38038861/) | 0.90 | 2024 | Current environmental health reports | review_meta | individual | Meta-analysis: wildfire PM2.5 raised URI risk 13% and birthweight fell 22g per 10 ug/m3 in children. |
| [38085772](https://pubmed.ncbi.nlm.nih.gov/38085772/) | 0.90 | 2023 | Proceedings of the National Academy of S | quasi_experimental | national | US 2006-20: majority of smoke-related asthma ED visits attributable to out-of-county fires; individual fire severity poorly predicts asthma burden. |
| [26346113](https://pubmed.ncbi.nlm.nih.gov/26346113/) | 0.90 | 2016 | Respirology (Carlton, Vic.) | quasi_experimental | state | Victoria 2006-07 bushfires: 8.6 ug/m3 PM2.5 raised same-day asthma ED visits 2% overall; 5% among women 20+. |
| [40209994](https://pubmed.ncbi.nlm.nih.gov/40209994/) | 0.80 | 2025 | Environmental research | review_meta | national | Systematic review: 12 studies consistently show wildfire smoke exposure raises asthma reliever (salbutamol) medication use. |

## 3.3 Top-relevance abstracts — air_quality (15 shown of 37)

| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |
|---|---:|---:|---|---|---|---|
| [40279132](https://pubmed.ncbi.nlm.nih.gov/40279132/) | 0.80 | 2026 | International journal of environmental h | time_series | neighborhood | In Pittsburgh EJ area, PM2.5 10-12 ug/m3 raised asthma-student absenteeism 27% and SO2 >=75 ppb raised it 85% versus low-exposure days. |
| [39406285](https://pubmed.ncbi.nlm.nih.gov/39406285/) | 0.80 | 2024 | Environmental research | cohort_observational | neighborhood | Near the drying Salton Sea, each 100 dust-storm hrs/yr raised child wheeze prevalence by 9.5 percentage points. |
| [37310769](https://pubmed.ncbi.nlm.nih.gov/37310769/) | 0.80 | 2023 | The Journal of asthma : official journal | cohort_observational | county | Bronx pediatric admits: 10 ug/m3 PM2.5 raised asthma LOS 10.6%; 10 ppbv O3 raised LOS 3.9%. |
| [35073244](https://pubmed.ncbi.nlm.nih.gov/35073244/) | 0.80 | 2022 | American journal of respiratory and crit | time_series | national | US Medicaid: 1 ug/m3 PM2.5 raised asthma hospitalization risk 0.31%, effects persisting below current NAAQS. |
| [33676951](https://pubmed.ncbi.nlm.nih.gov/33676951/) | 0.80 | 2021 | Environmental research | time_series | county | Philadelphia: interquartile PM2.5 rise raised child asthma exacerbation odds up to 5% in cold months and 3% in warm months. |
| [41214648](https://pubmed.ncbi.nlm.nih.gov/41214648/) | 0.70 | 2025 | BMC public health | cohort_observational | household | UK Born in Bradford: indoor PM2.5 averaged 20 ug/m3, higher in South Asian and deprived homes; no significant asthma symptom link found. |
| [40387788](https://pubmed.ncbi.nlm.nih.gov/40387788/) | 0.70 | 2025 | Environmental science & technology | cross_sectional | national | MANE model: diesel HDV NOx emissions cause about 4% of US pediatric asthma cases; Black children bear 65-100% higher per-capita rates. |
| [39038774](https://pubmed.ncbi.nlm.nih.gov/39038774/) | 0.70 | 2024 | Environmental pollution (Barking, Essex  | time_series | county | In NYS 2014-19, excess rates of asthma/COPD ED visits per unit PM2.5 rose after Tier 3 rule; disparities persisted for Black and Hispanic residents. |
| [42323982](https://pubmed.ncbi.nlm.nih.gov/42323982/) | 0.60 | 2026 | Respiratory medicine | cross_sectional | national | GBD 2021: environmental/occupational risks account for 13.9% of asthma DALYs in young adults 5-39; burden projected to rise to 2050. |
| [42287544](https://pubmed.ncbi.nlm.nih.gov/42287544/) | 0.60 | 2026 | Current allergy and asthma reports | review_meta | individual | Review: prenatal/early-life PM2.5, NO2, ozone and heavy metals increase childhood asthma incidence via oxidative stress and epigenetic pathways. |
| [39865338](https://pubmed.ncbi.nlm.nih.gov/39865338/) | 0.60 | 2025 | Genetic epidemiology | cohort_observational | individual | Southern California cohort: PRS-NO2 interaction on childhood asthma incidence is borderline; PRS unpredictive in Hispanic children. |
| [38908569](https://pubmed.ncbi.nlm.nih.gov/38908569/) | 0.60 | 2024 | Preventive medicine | cohort_observational | neighborhood | Among NYC Medicaid kids in subsidized housing, adjusting for pollution and built-env risks attenuated but did not erase Black/Hispanic asthma disparities. |
| [38445892](https://pubmed.ncbi.nlm.nih.gov/38445892/) | 0.60 | 2024 | Environmental health perspectives | time_series | national | US 2010-19: racial/ethnic disparities in NO2-attributable pediatric asthma widened 10-19% despite falling overall pollution burden. |
| [35358226](https://pubmed.ncbi.nlm.nih.gov/35358226/) | 0.60 | 2022 | PloS one | cross_sectional | county | Pennsylvania: county well density from fracking associated with 3% increase in asthma hospitalization admission rates. |
| [29690596](https://pubmed.ncbi.nlm.nih.gov/29690596/) | 0.60 | 2018 | International journal of environmental r | time_series | county | Taiwan: PM2.5 rising to 64.7 ug/m3 raised child clinic visits for asthma by 8% with up to 6-day lag. |

## 3.4 Top-relevance abstracts — heat (3 shown of 3)

| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |
|---|---:|---:|---|---|---|---|
| [42208373](https://pubmed.ncbi.nlm.nih.gov/42208373/) | 0.90 | 2026 | Environment international | time_series | national | 20-yr GP time series: co-exposure to extreme heat + high pollen synergistically raised allergic rhinitis and asthma risk (RERI 0.48). |
| [36208788](https://pubmed.ncbi.nlm.nih.gov/36208788/) | 0.90 | 2023 | Environmental research | review_meta | national | Meta-analysis: extreme heat (RR 1.07) and extreme cold (RR 1.20) both significantly raised asthma attack risk. |
| [35189885](https://pubmed.ncbi.nlm.nih.gov/35189885/) | 0.90 | 2022 | Respiratory research | time_series | county | Beijing 2012-15: 29% of adult asthma hospitalizations attributable to non-optimum temperatures, mostly moderate cold. |

## 3.5 Top-relevance abstracts — filtration_hepa (15 shown of 27)

| PMID | Rel | Year | Journal | Study | N-scale | Bottom line |
|---|---:|---:|---|---|---|---|
| [41979079](https://pubmed.ncbi.nlm.nih.gov/41979079/) | 1.00 | 2026 | Journal of environmental science and hea | rct | individual | RCT: HEPA H14 purifiers cut indoor PM2.5 by 29.6 ug/m3 and raised Asthma Control Test score by 2.2 points over 8 months. |
| [38388489](https://pubmed.ncbi.nlm.nih.gov/38388489/) | 1.00 | 2024 | Thorax | rct | individual | MEDEA RCT: HEPA plus dust-storm alerts improved child ACT score by 2.6 and FEV1 by 4.3% during Cyprus/Greece dust season. |
| [40380354](https://pubmed.ncbi.nlm.nih.gov/40380354/) | 0.90 | 2025 | Allergy and asthma proceedings | rct | individual | Cost-effectiveness of SICAS2: combined school IPM+HEPA saved $19,667/QALY in student asthma management. |
| [40246248](https://pubmed.ncbi.nlm.nih.gov/40246248/) | 0.90 | 2025 | Respiratory medicine | rct | individual | RCT: Dyson HEPA H13 delayed early asthmatic response and cut cat rhino-conjunctivitis scores 52% in exposure chamber. |
| [37917367](https://pubmed.ncbi.nlm.nih.gov/37917367/) | 0.90 | 2024 | American journal of respiratory and crit | quasi_experimental | state | Markov model: HEPA filter subsidies prevent 4,418 exacerbations over 5 years in BC and are cost-effective at $75k/QALY. |
| [37917367](https://pubmed.ncbi.nlm.nih.gov/37917367/) | 0.90 | 2024 | American journal of respiratory and crit | quasi_experimental | state | Markov model: HEPA filter subsidies prevent 4,418 exacerbations over 5 years in BC and are cost-effective at $75k/QALY. |
| [35796019](https://pubmed.ncbi.nlm.nih.gov/35796019/) | 0.90 | 2023 | The Journal of asthma : official journal | rct | individual | Triple-crossover RCT: HEPA (particle reduction) trended toward 1.8 fewer child asthma symptom days/14; NO2 scrubber alone no benefit. |
| [34547084](https://pubmed.ncbi.nlm.nih.gov/34547084/) | 0.90 | 2021 | JAMA | rct | individual | SICAS2 RCT: school-wide IPM or classroom HEPA did not significantly reduce asthma symptom-days in urban students. |
| [32831855](https://pubmed.ncbi.nlm.nih.gov/32831855/) | 0.85 | 2020 | Journal of environmental and public heal | other | household | Pilot US-Mexico border: air purifier plus asthma education cut mean PM2.5 by 1.9 ug/m3 and improved child quality of life. |
| [28935614](https://pubmed.ncbi.nlm.nih.gov/28935614/) | 0.85 | 2017 | Environmental health perspectives | rct | household | Placebo-controlled RCT: HEPA filter in woodstove homes cut indoor PM2.5 67% and reduced diurnal peak-flow variability 4.1%. |
| [35341426](https://pubmed.ncbi.nlm.nih.gov/35341426/) | 0.80 | 2023 | The Journal of asthma : official journal | rct | individual | Post-hoc SICAS2: classroom HEPA lowered mold ERMI values and raised student FEV1% by 4.2 points vs sham. |
| [34980119](https://pubmed.ncbi.nlm.nih.gov/34980119/) | 0.80 | 2022 | Environmental health : a global access s | rct | individual | Latino agricultural children's RCT: HEPA reduced clinically poor ACT (IRR 0.45) and unplanned utilization (IRR 0.35). |
| [33096665](https://pubmed.ncbi.nlm.nih.gov/33096665/) | 0.80 | 2020 | International journal of environmental r | rct | individual | Korean crossover RCT: HEPA filters cut indoor PM2.5 43%; each 1 ug/m3 rise lowered peak expiratory flow 0.2% daily in asthmatic children. |
| [38560887](https://pubmed.ncbi.nlm.nih.gov/38560887/) | 0.75 | 2024 | Journal of occupational and environmenta | other | household | Pilot: HEPA purifiers and HEPA vacuums in 5 pediatric-asthma homes were feasible with low-cost IAQ monitoring. |
| [38560887](https://pubmed.ncbi.nlm.nih.gov/38560887/) | 0.75 | 2024 | Journal of occupational and environmenta | other | household | Pilot: HEPA purifiers and HEPA vacuums in 5 pediatric-asthma homes were feasible with low-cost IAQ monitoring. |

## 4. Synthesis: literature-supported causal claims

Filtering to `relevance >= 0.80` abstracts with a direct causal claim yields
the following high-confidence findings from the peer-reviewed evidence base:

### air_quality
- **PMID [40279132](https://pubmed.ncbi.nlm.nih.gov/40279132/) (2026, International journal of envir)** — In Pittsburgh EJ area, PM2.5 10-12 ug/m3 raised asthma-student absenteeism 27% and SO2 >=75 ppb raised it 85% versus low-exposure days.
- **PMID [39406285](https://pubmed.ncbi.nlm.nih.gov/39406285/) (2024, Environmental research)** — Near the drying Salton Sea, each 100 dust-storm hrs/yr raised child wheeze prevalence by 9.5 percentage points.
- **PMID [37310769](https://pubmed.ncbi.nlm.nih.gov/37310769/) (2023, The Journal of asthma : offici)** — Bronx pediatric admits: 10 ug/m3 PM2.5 raised asthma LOS 10.6%; 10 ppbv O3 raised LOS 3.9%.
- **PMID [35073244](https://pubmed.ncbi.nlm.nih.gov/35073244/) (2022, American journal of respirator)** — US Medicaid: 1 ug/m3 PM2.5 raised asthma hospitalization risk 0.31%, effects persisting below current NAAQS.
- **PMID [33676951](https://pubmed.ncbi.nlm.nih.gov/33676951/) (2021, Environmental research)** — Philadelphia: interquartile PM2.5 rise raised child asthma exacerbation odds up to 5% in cold months and 3% in warm months.

### filtration_hepa
- **PMID [41979079](https://pubmed.ncbi.nlm.nih.gov/41979079/) (2026, Journal of environmental scien)** — RCT: HEPA H14 purifiers cut indoor PM2.5 by 29.6 ug/m3 and raised Asthma Control Test score by 2.2 points over 8 months.
- **PMID [38388489](https://pubmed.ncbi.nlm.nih.gov/38388489/) (2024, Thorax)** — MEDEA RCT: HEPA plus dust-storm alerts improved child ACT score by 2.6 and FEV1 by 4.3% during Cyprus/Greece dust season.
- **PMID [37917367](https://pubmed.ncbi.nlm.nih.gov/37917367/) (2024, American journal of respirator)** — Markov model: HEPA filter subsidies prevent 4,418 exacerbations over 5 years in BC and are cost-effective at $75k/QALY.
- **PMID [40380354](https://pubmed.ncbi.nlm.nih.gov/40380354/) (2025, Allergy and asthma proceedings)** — Cost-effectiveness of SICAS2: combined school IPM+HEPA saved $19,667/QALY in student asthma management.
- **PMID [40246248](https://pubmed.ncbi.nlm.nih.gov/40246248/) (2025, Respiratory medicine)** — RCT: Dyson HEPA H13 delayed early asthmatic response and cut cat rhino-conjunctivitis scores 52% in exposure chamber.
- **PMID [37917367](https://pubmed.ncbi.nlm.nih.gov/37917367/) (2024, American journal of respirator)** — Markov model: HEPA filter subsidies prevent 4,418 exacerbations over 5 years in BC and are cost-effective at $75k/QALY.
- **PMID [35796019](https://pubmed.ncbi.nlm.nih.gov/35796019/) (2023, The Journal of asthma : offici)** — Triple-crossover RCT: HEPA (particle reduction) trended toward 1.8 fewer child asthma symptom days/14; NO2 scrubber alone no benefit.
- **PMID [34547084](https://pubmed.ncbi.nlm.nih.gov/34547084/) (2021, JAMA)** — SICAS2 RCT: school-wide IPM or classroom HEPA did not significantly reduce asthma symptom-days in urban students.
- **PMID [32831855](https://pubmed.ncbi.nlm.nih.gov/32831855/) (2020, Journal of environmental and p)** — Pilot US-Mexico border: air purifier plus asthma education cut mean PM2.5 by 1.9 ug/m3 and improved child quality of life.
- **PMID [28935614](https://pubmed.ncbi.nlm.nih.gov/28935614/) (2017, Environmental health perspecti)** — Placebo-controlled RCT: HEPA filter in woodstove homes cut indoor PM2.5 67% and reduced diurnal peak-flow variability 4.1%.
- **PMID [35341426](https://pubmed.ncbi.nlm.nih.gov/35341426/) (2023, The Journal of asthma : offici)** — Post-hoc SICAS2: classroom HEPA lowered mold ERMI values and raised student FEV1% by 4.2 points vs sham.
- **PMID [34980119](https://pubmed.ncbi.nlm.nih.gov/34980119/) (2022, Environmental health : a globa)** — Latino agricultural children's RCT: HEPA reduced clinically poor ACT (IRR 0.45) and unplanned utilization (IRR 0.35).
- **PMID [33096665](https://pubmed.ncbi.nlm.nih.gov/33096665/) (2020, International journal of envir)** — Korean crossover RCT: HEPA filters cut indoor PM2.5 43%; each 1 ug/m3 rise lowered peak expiratory flow 0.2% daily in asthmatic children.

### heat
- **PMID [42208373](https://pubmed.ncbi.nlm.nih.gov/42208373/) (2026, Environment international)** — 20-yr GP time series: co-exposure to extreme heat + high pollen synergistically raised allergic rhinitis and asthma risk (RERI 0.48).
- **PMID [36208788](https://pubmed.ncbi.nlm.nih.gov/36208788/) (2023, Environmental research)** — Meta-analysis: extreme heat (RR 1.07) and extreme cold (RR 1.20) both significantly raised asthma attack risk.
- **PMID [35189885](https://pubmed.ncbi.nlm.nih.gov/35189885/) (2022, Respiratory research)** — Beijing 2012-15: 29% of adult asthma hospitalizations attributable to non-optimum temperatures, mostly moderate cold.

### outage
- **PMID [41979329](https://pubmed.ncbi.nlm.nih.gov/41979329/) (2026, Epidemiology (Cambridge, Mass.)** — NYC power outages associated with elevated asthma ED visits, especially among NYCHA children during summer (OR 2.23 lag 0-1).
- **PMID [33583411](https://pubmed.ncbi.nlm.nih.gov/33583411/) (2021, Environmental health : a globa)** — Modeling: energy-efficiency retrofits with mechanical ventilation save >$200/yr/child asthma costs; retrofits without ventilation raise costs.

### wildfire_smoke
- **PMID [42414291](https://pubmed.ncbi.nlm.nih.gov/42414291/) (2026, Nature communications)** — Brazil 2000-19: 1 ug/m3 wildfire PM2.5 raised asthma hospital cost 1.6% and length of stay 1.7% across 184M admissions.
- **PMID [41720420](https://pubmed.ncbi.nlm.nih.gov/41720420/) (2026, American journal of obstetrics)** — In pregnant asthmatic Australians, >=10 days of wildfire smoke raised low birthweight OR 4.2, preterm birth OR 2.8, NICU admit OR 5.0.
- **PMID [40480103](https://pubmed.ncbi.nlm.nih.gov/40480103/) (2025, Environment international)** — Reno 2012-19: 10 ug/m3 wildfire PM2.5 raised asthma ED/urgent-care visits 4-7%, larger effects from high-intensity forest fire smoke.
- **PMID [40324806](https://pubmed.ncbi.nlm.nih.gov/40324806/) (2025, CMAJ : Canadian Medical Associ)** — Ontario June 2023 wildfire smoke episode raised asthma-related ED visits 23.6% at lag 1 day, with sustained adult surge.
- **PMID [37722035](https://pubmed.ncbi.nlm.nih.gov/37722035/) (2023, Proceedings of the National Ac)** — California 2006-17: wildfire smoke raised asthma/COPD/cough ED visits 30-110% in week after extreme smoke days.
- **PMID [37616233](https://pubmed.ncbi.nlm.nih.gov/37616233/) (2023, MMWR. Morbidity and mortality )** — US April-Aug 2023: Canadian wildfire smoke days raised asthma-related ED visits 17% overall, larger in age 5-64.
- **PMID [36767304](https://pubmed.ncbi.nlm.nih.gov/36767304/) (2023, International journal of envir)** — Calgary 2010-21: wildfire smoke days raised pediatric asthma exacerbations 13% (IRR 1.13) versus baseline.
- **PMID [32854703](https://pubmed.ncbi.nlm.nih.gov/32854703/) (2020, Environmental health : a globa)** — Reno 2013-18: wildfire smoke amplified asthma-visit association with 5 ug/m3 PM2.5 by ~6%.
- **PMID [32051501](https://pubmed.ncbi.nlm.nih.gov/32051501/) (2020, Journal of exposure science & )** — Oregon 2013: 10 ug/m3 wildfire PM2.5 raised asthma ED visits 8.9%, office visits 5% and rescue-inhaler fills 7.7%.
- **PMID [41899691](https://pubmed.ncbi.nlm.nih.gov/41899691/) (2026, International journal of envir)** — Early-gestation wildfire PM2.5 exposure associated with altered infant tidal flows and 36% higher odds of asthma at age 6.
- **PMID [41372919](https://pubmed.ncbi.nlm.nih.gov/41372919/) (2025, Environmental health : a globa)** — Vermont/upstate NY: pediatric asthma control was worse in the smoke-affected summer 2023 versus 2022, but ZIP-code PM2.5 not consistently linked.
- **PMID [38085772](https://pubmed.ncbi.nlm.nih.gov/38085772/) (2023, Proceedings of the National Ac)** — US 2006-20: majority of smoke-related asthma ED visits attributable to out-of-county fires; individual fire severity poorly predicts asthma burden.
- **PMID [38038861](https://pubmed.ncbi.nlm.nih.gov/38038861/) (2024, Current environmental health r)** — Meta-analysis: wildfire PM2.5 raised URI risk 13% and birthweight fell 22g per 10 ug/m3 in children.
- **PMID [26346113](https://pubmed.ncbi.nlm.nih.gov/26346113/) (2016, Respirology (Carlton, Vic.))** — Victoria 2006-07 bushfires: 8.6 ug/m3 PM2.5 raised same-day asthma ED visits 2% overall; 5% among women 20+.
- **PMID [40209994](https://pubmed.ncbi.nlm.nih.gov/40209994/) (2025, Environmental research)** — Systematic review: 12 studies consistently show wildfire smoke exposure raises asthma reliever (salbutamol) medication use.
- **PMID [38622704](https://pubmed.ncbi.nlm.nih.gov/38622704/) (2024, Environmental health : a globa)** — Western Montana pediatric visits: 1 ug/m3 PM2.5 lagged 7-13 days raised asthma odds, magnified by cold temperatures.
- **PMID [35742668](https://pubmed.ncbi.nlm.nih.gov/35742668/) (2022, International journal of envir)** — Australia 2019-20 bushfires: 83% of adults with severe asthma had symptoms; 44% needed oral corticosteroids; 65% had persistent symptoms.
- **PMID [31146163](https://pubmed.ncbi.nlm.nih.gov/31146163/) (2019, Environment international)** — California 2008 wildfires: 10 ug/m3 smoke PM2.5 raised asthma ED visits 11.2%; ozone effect confounded by PM.
- **PMID [25747784](https://pubmed.ncbi.nlm.nih.gov/25747784/) (2015, Annals of allergy, asthma & im)** — Southern California 2003/2007 fires: SABA dispensations rose most in obese children with asthma post-wildfire.

