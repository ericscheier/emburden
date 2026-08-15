#!/usr/bin/env python3
"""
CDC WONDER Selenium Scraper — Cause-Specific County Mortality (2018-2023)
=========================================================================

PURPOSE:
    Download county-level cause-specific mortality data from CDC WONDER for
    all 51 states (50 states + DC). Covers 61 cause groups spanning all major
    ICD-10 chapters, aligned to NCHS 358 / NCHS 113 / WHO ICD-10 Tabulation
    Lists 1 & 2, with 8 CUSTOM composites for energy/climate research.

    Categories: energy/climate hazards, circulatory, respiratory, infectious,
    neoplasms, blood, endocrine, mental, nervous system, digestive,
    genitourinary, maternal, perinatal, congenital, symptoms/ill-defined,
    and all external causes (drug, suicide, homicide, falls, MVT, etc.).

DATASET:
    CDC WONDER Underlying Cause of Death, Expanded (D158), 2018-2023
    URL: https://wonder.cdc.gov/ucd-icd10-expanded.html

ICD-10 SELECTION:
    Uses the WONDER form's advanced-mode textarea (V_D158.V2) with
    O_V2_fmode = "fadv".  Codes are entered one per line; ranges like
    "X40-X44" are accepted by the WONDER form.

OUTPUT FILES:
    ../sources/cdc_wonder_downloads_causes/
      mortality_{FIPS}_{StateName}_{cause_key}.txt  — tab-delimited TSV
      mortality_{FIPS}_{StateName}_{cause_key}.NODATA — marker when query
                                                         returned no rows

SKIP LOGIC:
    Any state×cause pair with an existing .txt or .NODATA file is skipped.
    Safe to re-run after interruption.

RATE LIMIT:
    120 seconds between queries (CDC WONDER recommendation).  With 51 states
    × 61 causes = 3,111 queries, full run takes ~104 hours (~4.3 nights).
    Use --causes and --states to batch across nights.  Re-runnable: existing
    .txt and .NODATA files are skipped automatically.

REQUIREMENTS:
    pip install selenium
    Chrome / Chromium + ChromeDriver in PATH

NEXT STEP:
    After scraping completes, run:
      Rscript /tmp/migrate_cdc_wonder_causes_to_cache.R
    to populate ~/.cache/emburdendata/cdc_wonder/ with
      wonder_{FIPS}_2018_2023_{cause_key}.rds
"""

import json
import os
import sys
import time
import glob
import argparse

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import Select, WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, NoSuchElementException

# ==============================================================================
# CONFIGURATION
# ==============================================================================

CDC_WONDER_URL = "https://wonder.cdc.gov/ucd-icd10-expanded.html"

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "sources", "cdc_wonder_downloads_causes"
)

WAIT_TIMEOUT   = 30   # seconds
RATE_LIMIT     = 120  # seconds between queries (CDC recommendation)
QUERY_YEARS    = ["2018", "2019", "2020", "2021", "2022", "2023"]

# All 51 states (50 + DC), FIPS → name
ALL_STATES = {
    "01": "Alabama", "02": "Alaska", "04": "Arizona", "05": "Arkansas",
    "06": "California", "08": "Colorado", "09": "Connecticut", "10": "Delaware",
    "11": "District_of_Columbia", "12": "Florida", "13": "Georgia",
    "15": "Hawaii", "16": "Idaho", "17": "Illinois", "18": "Indiana",
    "19": "Iowa", "20": "Kansas", "21": "Kentucky", "22": "Louisiana",
    "23": "Maine", "24": "Maryland", "25": "Massachusetts", "26": "Michigan",
    "27": "Minnesota", "28": "Mississippi", "29": "Missouri", "30": "Montana",
    "31": "Nebraska", "32": "Nevada", "33": "New_Hampshire", "34": "New_Jersey",
    "35": "New_Mexico", "36": "New_York", "37": "North_Carolina",
    "38": "North_Dakota", "39": "Ohio", "40": "Oklahoma", "41": "Oregon",
    "42": "Pennsylvania", "44": "Rhode_Island", "45": "South_Carolina",
    "46": "South_Dakota", "47": "Tennessee", "48": "Texas", "49": "Utah",
    "50": "Vermont", "51": "Virginia", "53": "Washington",
    "54": "West_Virginia", "55": "Wisconsin", "56": "Wyoming",
}

# Cause groups: key → {label, icd_codes (one per line in WONDER textarea)}
# Codes are entered in advanced-mode textarea; ranges like "X40-X44" work.
#
# ALIGNMENT WITH ESTABLISHED CLASSIFICATIONS
# ─────────────────────────────────────────────────────────────────────────────
# Primary reference: NCHS Instruction Manual Part 9, Table A (358 Selected
#   Causes of Death) and Table B (113 Selected Causes of Death).
#   Source: https://ftp.cdc.gov/pub/health_statistics/NCHS/Manuals/Mortality/
# Secondary reference: WHO ICD-10 Mortality Tabulation Lists 1 (103 causes)
#   and 2 (80 causes), which underlie NCHS 358/113.
#
# Each cause is tagged with its alignment status:
#   EXACT     — code range matches NCHS 358/113 exactly
#   NARROWER  — our range is a proper subset of the NCHS group
#   BROADER   — our range exceeds the NCHS group (documented below)
#   CUSTOM    — not a named NCHS group; energy/climate-specific composite
#               or post-2002 addition (COVID). Documented individually.
#
# CUSTOM causes and their justification:
#   heat       X30     — "Exposure to excessive natural heat"; NCHS rolls into
#                        nontransport accidents residual; named separately here
#                        for energy/climate research (see: Bobb et al. 2014)
#   cold       X31,T68 — "Exposure to excessive cold" + "Hypothermia"; NCHS
#                        residual; separated for cold-weather/utility shutoff
#                        research (see: Bhaskaran et al. 2010)
#   heatstroke T67     — Mechanism code (not external cause); captures heat
#                        stroke/exhaustion when circumstances coded in T chapter
#   frostbite  T33-T35 — Mechanism code; cold exposure distinct from T68
#   co         T58     — CO poisoning mechanism; NCHS uses X47 for accidental
#                        gas poisoning (external cause axis). T58 captures all
#                        CO deaths regardless of intent.
#   asphyxiation T71   — Asphyxiation mechanism; not a named NCHS group
#   toxic_gas  T59     — Toxic gas mechanism (excl. CO); NCHS #329 uses X47
#                        (accidental only). T59 is intent-agnostic.
#   covid      U07.1-2 — WHO/NCHS emergency addition 2020; not in original
#                        358 list. Now tracked as ICD-10 U07 codes.
#   alcohol    composite — No single NCHS group covers all alcohol deaths.
#                        This composite (F10+K70+X45+Y15) follows NIAAA/CDC
#                        alcohol-attributable mortality methodology.
CAUSES = {
    # ════════════════════════════════════════════════════════════════
    # ENERGY / CLIMATE (CUSTOM — not named groups in NCHS 358/113)
    # ════════════════════════════════════════════════════════════════

    # ── Temperature extremes ──
    "heat": {                            # CUSTOM
        "label": "Heat-related (X30)",
        "icd_codes": "X30",
    },
    "cold": {                            # CUSTOM
        "label": "Cold/Hypothermia (X31, T68)",
        "icd_codes": "X31\nT68",
    },
    "heatstroke": {                      # CUSTOM (mechanism code T67)
        "label": "Heat stroke & exhaustion (T67)",
        "icd_codes": "T67",
    },
    "frostbite": {                       # CUSTOM (mechanism code T33-T35)
        "label": "Frostbite (T33-T35)",
        "icd_codes": "T33-T35",
    },
    # ── Home energy / infrastructure hazards ──
    "co": {                              # CUSTOM (mechanism code T58)
        "label": "Carbon monoxide (T58)",
        "icd_codes": "T58",
    },
    "fire": {                            # EXACT — NCHS 358 #322
        "label": "Smoke, fire & flames (X00-X09)",
        "icd_codes": "X00-X09",
    },
    "electro": {                         # EXACT — NCHS 358 #320
        "label": "Electrocution (W85-W87)",
        "icd_codes": "W85-W87",
    },
    "toxic_gas": {                       # CUSTOM (mechanism code T59; NCHS uses X47)
        "label": "Toxic gases excl. CO (T59)",
        "icd_codes": "T59",
    },
    "asphyxiation": {                    # CUSTOM (mechanism code T71)
        "label": "Asphyxiation (T71)",
        "icd_codes": "T71",
    },
    # ── Extreme weather events ──
    "storm": {                           # NARROWER — NCHS 358 #326 = X37-X38
        "label": "Cataclysmic storm — hurricane/tornado (X37)",
        "icd_codes": "X37",
    },
    "flood": {                           # BROADER — combines NCHS #317 (W65-W74) + #326 (X38)
        "label": "Flood & drowning (X38, W65-W74)",
        "icd_codes": "X38\nW65-W74",
    },
    "lightning": {                       # EXACT — NCHS 358 #324
        "label": "Lightning (X33)",
        "icd_codes": "X33",
    },

    # ════════════════════════════════════════════════════════════════
    # CIRCULATORY — NCHS 113 groups 50–72
    # ════════════════════════════════════════════════════════════════
    "cardio": {                          # BROADER — NCHS 'major cardiovascular' = I00-I78
        "label": "Cardiovascular, all (I00-I99)",
        "icd_codes": "I00-I99",
    },
    "hypertension": {                    # BROADER — NCHS splits I10,I11,I12,I13 into 4 groups
        "label": "Hypertensive disease (I10-I15)",
        "icd_codes": "I10-I15",
    },
    "ihd": {                             # EXACT — NCHS 113 #55
        "label": "Ischemic heart disease (I20-I25)",
        "icd_codes": "I20-I25",
    },
    "arrhythmia": {                      # NARROWER — NCHS 358 #177 = I44-I49; fix applied
        "label": "Conduction disorders & cardiac arrhythmia (I44-I49)",
        "icd_codes": "I44-I49",
    },
    "heartfail": {                       # EXACT — NCHS 113 #64
        "label": "Heart failure (I50)",
        "icd_codes": "I50",
    },
    "stroke": {                          # EXACT — NCHS 113 #67
        "label": "Cerebrovascular / stroke (I60-I69)",
        "icd_codes": "I60-I69",
    },

    # ════════════════════════════════════════════════════════════════
    # RESPIRATORY — NCHS 113 groups 73–86
    # ════════════════════════════════════════════════════════════════
    "resp": {                            # BROADER — NCHS splits J into 3+ groups
        "label": "Respiratory, all (J00-J99)",
        "icd_codes": "J00-J99",
    },
    "flu": {                             # BROADER — NCHS 358 #195 = J10-J11; J09 added for novel flu
        "label": "Influenza incl. novel strains (J09-J11)",
        "icd_codes": "J09-J11",
    },
    "pneumonia": {                       # EXACT — NCHS 113 #75
        "label": "Pneumonia (J12-J18)",
        "icd_codes": "J12-J18",
    },
    "copd": {                            # NARROWER — NCHS CLRD = J40-J47; J47 (bronchiectasis) excluded
        "label": "COPD (J40-J44)",
        "icd_codes": "J40-J44",
    },
    "asthma": {                          # EXACT — NCHS 358 #206 = J45-J46; fix applied
        "label": "Asthma (J45-J46)",
        "icd_codes": "J45-J46",
    },
    "pneumoconiosis": {                  # EXACT — NCHS 358 #208
        "label": "Pneumoconioses & chemical effects (J60-J66, J68)",
        "icd_codes": "J60-J66\nJ68",
    },

    # ════════════════════════════════════════════════════════════════
    # INFECTIOUS & PARASITIC — NCHS 113 groups 1–17
    # ════════════════════════════════════════════════════════════════
    "sepsis": {                          # EXACT — NCHS 358 #18
        "label": "Septicemia (A40-A41)",
        "icd_codes": "A40-A41",
    },
    "tb": {                              # EXACT — NCHS 113 #4+5
        "label": "Tuberculosis (A15-A19)",
        "icd_codes": "A15-A19",
    },
    "hepatitis": {                       # EXACT — NCHS 358 #38
        "label": "Viral hepatitis (B15-B19)",
        "icd_codes": "B15-B19",
    },
    "hiv": {                             # EXACT — NCHS 113 #16
        "label": "HIV / AIDS (B20-B24)",
        "icd_codes": "B20-B24",
    },
    "covid": {                           # CUSTOM — WHO/NCHS U07 addition 2020
        "label": "COVID-19 (U07.1, U07.2)",
        "icd_codes": "U07.1\nU07.2",
    },

    # ════════════════════════════════════════════════════════════════
    # NEOPLASMS — NCHS 113 groups 18–42
    # ════════════════════════════════════════════════════════════════
    "all_cancer": {                      # BROADER — NCHS malignant = C00-C97; D00-D49 added
        "label": "All neoplasms (C00-D49)",
        "icd_codes": "C00-D49",
    },
    "lung_cancer": {                     # EXACT — NCHS 358 #73
        "label": "Trachea, bronchus & lung cancer (C33-C34)",
        "icd_codes": "C33-C34",
    },
    "mesothelioma": {                    # EXACT — NCHS 358 #79
        "label": "Mesothelioma (C45)",
        "icd_codes": "C45",
    },

    # ════════════════════════════════════════════════════════════════
    # BLOOD / IMMUNE — NCHS 113 #43
    # ════════════════════════════════════════════════════════════════
    "anemia": {                          # EXACT — NCHS 113 #43
        "label": "Anemias incl. sickle-cell (D50-D64)",
        "icd_codes": "D50-D64",
    },

    # ════════════════════════════════════════════════════════════════
    # ENDOCRINE / METABOLIC / NUTRITIONAL — NCHS 113 groups 44–46
    # ════════════════════════════════════════════════════════════════
    "diabetes": {                        # EXACT — NCHS 113 #44
        "label": "Diabetes mellitus (E10-E14)",
        "icd_codes": "E10-E14",
    },
    "malnutrition": {                    # EXACT — NCHS 113 #45
        "label": "Malnutrition (E40-E46)",
        "icd_codes": "E40-E46",
    },
    "obesity": {                         # EXACT — NCHS 358 #132
        "label": "Obesity (E65-E68)",
        "icd_codes": "E65-E68",
    },

    # ════════════════════════════════════════════════════════════════
    # MENTAL / BEHAVIORAL — NCHS 358 groups 136–144
    # ════════════════════════════════════════════════════════════════
    "mental_all": {                      # BROADER — NCHS splits F into 9 subcategories
        "label": "All mental & behavioral disorders (F00-F99)",
        "icd_codes": "F00-F99",
    },
    "alcohol": {                         # CUSTOM composite — NIAAA/CDC methodology
        "label": "Alcohol-related (F10, K70, X45, Y15)",
        "icd_codes": "F10\nK70\nX45\nY15",
    },

    # ════════════════════════════════════════════════════════════════
    # NERVOUS SYSTEM — NCHS 358 groups 145–153
    # ════════════════════════════════════════════════════════════════
    "dementia": {                        # EXACT composite — NCHS 358 #136 (F01,F03) + #148 (G30)
        "label": "Alzheimer's & vascular dementia (G30, F01-F03)",
        "icd_codes": "G30\nF01-F03",
    },
    "parkinson": {                       # EXACT — NCHS 358 #147 = G20-G21; fix applied
        "label": "Parkinson's disease (G20-G21)",
        "icd_codes": "G20-G21",
    },
    "als": {                             # NARROWER — NCHS 358 #153 is broader; G10-G13 captures ALS/MND
        "label": "ALS & motor neuron disease (G10-G13)",
        "icd_codes": "G10-G13",
    },
    "ms": {                              # EXACT — NCHS 358 #149
        "label": "Multiple sclerosis (G35)",
        "icd_codes": "G35",
    },
    "epilepsy": {                        # EXACT — NCHS 358 #150
        "label": "Epilepsy (G40-G41)",
        "icd_codes": "G40-G41",
    },

    # ════════════════════════════════════════════════════════════════
    # DIGESTIVE — NCHS 358 groups 215–237
    # ════════════════════════════════════════════════════════════════
    "liver": {                           # BROADER — NCHS #90 = K70,K73-K74; K71-K72,K75-K76 added
        "label": "Liver disease (K70-K77)",
        "icd_codes": "K70-K77",
    },
    "pancreatitis": {                    # EXACT — NCHS 358 #235; fix applied (was K85-K86)
        "label": "Pancreatitis (K85, K86.0-K86.1)",
        "icd_codes": "K85\nK86.0-K86.1",
    },

    # ════════════════════════════════════════════════════════════════
    # GENITOURINARY — NCHS 113 groups 94–100
    # ════════════════════════════════════════════════════════════════
    "renal": {                           # EXACT — NCHS 358 #251
        "label": "Renal failure (N17-N19)",
        "icd_codes": "N17-N19",
    },
    "nephritis": {                       # BROADER — NCHS nephritis = N00-N07,N25-N27; we add N08-N16
        "label": "Nephritis & nephrotic syndrome (N00-N16)",
        "icd_codes": "N00-N16",
    },

    # ════════════════════════════════════════════════════════════════
    # MATERNAL — NCHS 113 group 102
    # ════════════════════════════════════════════════════════════════
    "maternal": {                        # EXACT — NCHS 113 #102
        "label": "Maternal conditions (O00-O99)",
        "icd_codes": "O00-O99",
    },

    # ════════════════════════════════════════════════════════════════
    # PERINATAL — NCHS 113 group 105
    # ════════════════════════════════════════════════════════════════
    "perinatal": {                       # EXACT — NCHS 113 #105
        "label": "Perinatal conditions (P00-P96)",
        "icd_codes": "P00-P96",
    },
    "sids": {                              # EXACT — NCHS 358 #295
        "label": "Sudden infant death syndrome (R95)",
        "icd_codes": "R95",
    },

    # ════════════════════════════════════════════════════════════════
    # CONGENITAL — NCHS 113 group 106
    # ════════════════════════════════════════════════════════════════
    "congen_heart": {                      # NARROWER — NCHS 358 #281 = Q20-Q28; major CHD subset
        "label": "Congenital heart defects (Q20-Q24)",
        "icd_codes": "Q20-Q24",
    },
    "all_congen": {                        # EXACT — NCHS 113 #106 = Q00-Q99
        "label": "All congenital malformations (Q00-Q99)",
        "icd_codes": "Q00-Q99",
    },

    # ════════════════════════════════════════════════════════════════
    # SYMPTOMS / ILL-DEFINED — NCHS 113 groups 108–109
    # ════════════════════════════════════════════════════════════════
    "senility": {                          # EXACT — NCHS 358 #292
        "label": "Senility (R54)",
        "icd_codes": "R54",
    },
    "ill_defined": {                       # EXACT — NCHS 113 #109 = R96-R99; fix applied (was R96,R99)
        "label": "Ill-defined & unknown cause of death (R96-R99)",
        "icd_codes": "R96-R99",
    },

    # ════════════════════════════════════════════════════════════════
    # EXTERNAL CAUSES — NCHS 113 groups 111–130
    # ════════════════════════════════════════════════════════════════

    # ── Substance use ──
    "drug": {                              # EXACT — NCHS 358 composite (drug overdose/poisoning)
        "label": "Drug overdose & poisoning (X40-X44, X60-X64, X85, Y10-Y14)",
        "icd_codes": "X40-X44\nX60-X64\nX85\nY10-Y14",
    },

    # ── Self-harm ──
    "suicide": {                           # EXACT — NCHS 113 #124 = X65-X84,Y87.0; fix applied (was X71-X84)
        "label": "Intentional self-harm / suicide (X65-X84, Y87.0)",
        "icd_codes": "X65-X84\nY87.0",
    },

    # ── Interpersonal violence ──
    "homicide": {                          # EXACT — NCHS 113 #125 = X85-Y09, Y87.1
        "label": "Assault / homicide (X85-Y09, Y87.1)",
        "icd_codes": "X85-Y09\nY87.1",     # U01-U02 dropped: WONDER form rejects
    },

    # ── Unintentional injuries ──
    "falls": {                             # EXACT — NCHS 358 #310
        "label": "Falls (W00-W19)",
        "icd_codes": "W00-W19",
    },
    "motor_vehicle": {                     # BROADER — NCHS MVT uses complex V-code logic; V01-V99 simplification
        "label": "Motor vehicle accidents (V01-V99)",
        "icd_codes": "V01-V99",
    },
    "all_external": {                      # BROADER — NCHS 113 #111 = V01-Y89; Y90-Y98 added
        "label": "All external causes of injury (V01-Y98)",
        "icd_codes": "V01-Y98",
    },

    # ── Undetermined intent ──
    "undetermined": {                      # EXACT — NCHS 113 #127 = Y10-Y34,Y87.2
        "label": "Events of undetermined intent (Y10-Y34, Y87.2)",
        "icd_codes": "Y10-Y34\nY87.2",
    },
}

# ==============================================================================
# WEBDRIVER SETUP
# ==============================================================================

def setup_driver(download_dir, headless=True):
    """Initialize Chrome WebDriver with configured download directory."""
    opts = Options()
    if headless:
        opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--window-size=1920,1080")

    prefs = {
        "download.default_directory":  os.path.abspath(download_dir),
        "download.prompt_for_download": False,
        "download.directory_upgrade":  True,
        "safebrowsing.enabled":        False,
        "profile.default_content_setting_values.automatic_downloads": 1,
    }
    opts.add_experimental_option("prefs", prefs)

    driver = webdriver.Chrome(options=opts)
    print(f"  Chrome initialised  (download dir: {os.path.abspath(download_dir)})", flush=True)
    return driver

# ==============================================================================
# HELPERS
# ==============================================================================

def wait_for_element(driver, by, value, timeout=WAIT_TIMEOUT):
    try:
        return WebDriverWait(driver, timeout).until(
            EC.presence_of_element_located((by, value))
        )
    except TimeoutException:
        return None

def wait_for_download(download_dir, initial_count, timeout=60):
    """Wait until a new (non-.crdownload) file appears."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        current = [f for f in glob.glob(os.path.join(download_dir, "*"))
                   if not f.endswith(".crdownload")]
        if len(current) > initial_count:
            time.sleep(2)
            return True
        time.sleep(1)
    return False

def deselect_all(driver, field_name):
    """Deselect the '*All*' option from a multi-select."""
    try:
        sel = Select(driver.find_element(By.NAME, field_name))
        sel.deselect_by_value("*All*")
    except Exception:
        pass

# ==============================================================================
# CORE SCRAPE FUNCTION
# ==============================================================================

def scrape_state_cause(driver, state_fips, state_name, cause_key, cause_info,
                       years, download_dir):
    """
    Scrape county-level mortality for one state × one cause group.

    Returns:
        "ok"      — downloaded successfully
        "nodata"  — query ran but CDC returned no county rows
        "error"   — something went wrong (retry candidate)
    """
    icd_codes = cause_info["icd_codes"]
    cause_label = cause_info["label"]

    print(f"\n  [{state_fips}] {state_name}  cause={cause_key}  ({cause_label})", flush=True)

    try:
        initial_count = len([f for f in glob.glob(os.path.join(download_dir, "*"))
                             if not f.endswith(".crdownload")])

        # ------------------------------------------------------------------
        # 1. Load form
        # ------------------------------------------------------------------
        driver.get(CDC_WONDER_URL)
        time.sleep(3)

        # ------------------------------------------------------------------
        # 2. Accept terms
        # ------------------------------------------------------------------
        agree = wait_for_element(driver, By.NAME, "action-I Agree")
        if not agree:
            print("    ✗ 'I Agree' button not found", flush=True)
            return "error"
        agree.click()
        time.sleep(2)

        # ------------------------------------------------------------------
        # 3. Group By: County (B_1) and Year (B_2)
        # ------------------------------------------------------------------
        try:
            Select(driver.find_element(By.NAME, "B_1")).select_by_value("D158.V9-level2")
        except Exception as e:
            print(f"    ✗ B_1 (County) selection failed: {e}", flush=True)
            return "error"

        try:
            Select(driver.find_element(By.NAME, "B_2")).select_by_value("D158.V1-level1")
        except Exception as e:
            print(f"    ✗ B_2 (Year) selection failed: {e}", flush=True)
            return "error"

        time.sleep(0.5)

        # ------------------------------------------------------------------
        # 4. State filter
        # ------------------------------------------------------------------
        deselect_all(driver, "F_D158.V9")
        try:
            Select(driver.find_element(By.NAME, "F_D158.V9")).select_by_value(state_fips)
        except Exception as e:
            print(f"    ✗ State selection failed: {e}", flush=True)
            return "error"

        time.sleep(0.5)

        # ------------------------------------------------------------------
        # 5. Year filter
        # ------------------------------------------------------------------
        deselect_all(driver, "F_D158.V1")
        try:
            year_sel = Select(driver.find_element(By.NAME, "F_D158.V1"))
            for yr in years:
                year_sel.select_by_value(yr)
        except Exception as e:
            print(f"    ✗ Year selection failed: {e}", flush=True)
            return "error"

        time.sleep(0.5)

        # ------------------------------------------------------------------
        # 6. ICD-10 cause filter — switch to advanced mode and fill textarea
        # ------------------------------------------------------------------
        # Strategy:
        #   a) Change the hidden mode input to "fadv" (advanced)
        #   b) Fill the V_D158.V2 textarea with ICD-10 codes (one per line)
        #
        # The server reads O_V2_fmode to decide which field to use:
        #   freg → F_D158.V2 (multi-select browse)
        #   fadv → V_D158.V2 (free-text textarea)

        icd_js = json.dumps(icd_codes)  # safely escaped for JS

        cause_ok = driver.execute_script(f"""
            // Switch to advanced mode
            var modeField = document.querySelector('input[name="O_V2_fmode"]');
            if (!modeField) return 'no_mode_field';
            modeField.value = 'fadv';
            modeField.dispatchEvent(new Event('change', {{bubbles: true}}));

            // Fill the cause textarea
            var ta = document.querySelector('textarea[name="V_D158.V2"]');
            if (!ta) return 'no_textarea';
            ta.value = {icd_js};
            ta.dispatchEvent(new Event('change', {{bubbles: true}}));
            ta.dispatchEvent(new Event('input',  {{bubbles: true}}));

            return 'ok';
        """)

        if cause_ok != "ok":
            # Fallback: maybe the D158 expanded form uses slightly different IDs.
            # Try toggling the finder to advanced mode via the JS function.
            print(f"    ⚠ JS cause setup returned '{cause_ok}' — trying finder toggle", flush=True)
            try:
                driver.execute_script(
                    "if (typeof toggleFinder === 'function') "
                    "toggleFinder('D158.V2', 'D158.V2', 'fadv', 'freg');"
                )
                time.sleep(0.5)
                # Try again with the textarea
                cause_ok2 = driver.execute_script(f"""
                    var ta = document.querySelector('textarea[name="V_D158.V2"]');
                    if (!ta) return 'no_textarea_after_toggle';
                    ta.value = {icd_js};
                    return 'ok';
                """)
                if cause_ok2 != "ok":
                    print(f"    ✗ Could not set ICD codes (tried toggle): {cause_ok2}", flush=True)
                    return "error"
            except Exception as e:
                print(f"    ✗ Finder toggle failed: {e}", flush=True)
                return "error"

        print(f"    ✓ ICD codes set: {icd_codes!r}", flush=True)
        time.sleep(0.5)

        # ------------------------------------------------------------------
        # 7. Submit
        # ------------------------------------------------------------------
        try:
            driver.find_element(By.NAME, "action-Send").click()
        except Exception as e:
            print(f"    ✗ Submit failed: {e}", flush=True)
            return "error"

        # ------------------------------------------------------------------
        # 8. Wait for results
        # ------------------------------------------------------------------
        print("    ⏳ Waiting for results …", flush=True)
        time.sleep(10)

        # Check for export button — its presence means data is available.
        # Suppression notices in #error-messages are informational only.
        try:
            driver.find_element(By.ID, "export-type-toggle")
            # Data available
            try:
                notice = driver.find_element(By.ID, "error-messages").text.strip()
                if notice and "Messages:" not in notice:
                    print(f"    ⚠ CDC notice (non-fatal): {notice[:120]}", flush=True)
            except Exception:
                pass
        except NoSuchElementException:
            # No export button → truly no data for this state/cause
            try:
                err = driver.find_element(By.ID, "error-messages").text.strip()
                print(f"    ○ No data returned: {err[:200]}", flush=True)
            except Exception:
                print("    ○ No data returned (no error message either)", flush=True)
            # Save debug HTML
            debug_path = os.path.join(download_dir,
                                      f"debug_{state_fips}_{cause_key}_nodata.html")
            with open(debug_path, "w") as fh:
                fh.write(driver.page_source)
            return "nodata"

        # ------------------------------------------------------------------
        # 9. Export / download
        # ------------------------------------------------------------------
        try:
            driver.find_element(By.ID, "export-type-toggle").click()
            time.sleep(1)
            driver.find_element(By.NAME, "action-Export").click()
            time.sleep(1)
        except Exception as e:
            print(f"    ✗ Export click failed: {e}", flush=True)
            debug_path = os.path.join(download_dir,
                                      f"debug_{state_fips}_{cause_key}_export_err.html")
            with open(debug_path, "w") as fh:
                fh.write(driver.page_source)
            return "error"

        print("    ⏳ Waiting for file …", flush=True)
        if not wait_for_download(download_dir, initial_count, timeout=60):
            print("    ✗ Download timed out", flush=True)
            return "error"

        # Rename to standardised name
        new_files = [f for f in glob.glob(os.path.join(download_dir, "*"))
                     if not f.endswith(".crdownload")]
        if len(new_files) > initial_count:
            latest = max(new_files, key=os.path.getctime)
            target = os.path.join(download_dir,
                                  f"mortality_{state_fips}_{state_name}_{cause_key}.txt")
            try:
                os.rename(latest, target)
                print(f"    ✓ Saved: {os.path.basename(target)}", flush=True)
            except OSError:
                pass
        return "ok"

    except Exception as e:
        print(f"    ✗ Unexpected error: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return "error"

# ==============================================================================
# MAIN
# ==============================================================================

def parse_args():
    p = argparse.ArgumentParser(
        description="CDC WONDER cause-specific county mortality scraper")
    p.add_argument("--causes", nargs="+", choices=list(CAUSES.keys()),
                   default=list(CAUSES.keys()),
                   help="Cause groups to scrape (default: all)")
    p.add_argument("--states", nargs="+", metavar="FIPS",
                   default=list(ALL_STATES.keys()),
                   help="State FIPS codes to scrape (default: all 51)")
    p.add_argument("--rate-limit", type=int, default=RATE_LIMIT,
                   help=f"Seconds between queries (default: {RATE_LIMIT})")
    p.add_argument("--no-headless", action="store_true",
                   help="Show browser window (for debugging)")
    return p.parse_args()


def main():
    args = parse_args()

    abs_output = os.path.abspath(OUTPUT_DIR)
    os.makedirs(abs_output, exist_ok=True)

    causes_to_run = {k: CAUSES[k] for k in args.causes}
    states_to_run = {k: ALL_STATES[k] for k in args.states if k in ALL_STATES}

    # Build work list: skip already-done pairs
    todo = []
    for cause_key, cause_info in causes_to_run.items():
        for fips, state_name in states_to_run.items():
            txt  = os.path.join(abs_output, f"mortality_{fips}_{state_name}_{cause_key}.txt")
            nodt = os.path.join(abs_output, f"mortality_{fips}_{state_name}_{cause_key}.NODATA")
            if os.path.exists(txt) or os.path.exists(nodt):
                continue
            todo.append((fips, state_name, cause_key, cause_info))

    total   = len(causes_to_run) * len(states_to_run)
    already = total - len(todo)

    print("\n" + "="*70)
    print("  CDC WONDER CAUSE-SPECIFIC SCRAPER — 2018-2023 County Mortality")
    print("="*70)
    print(f"  Causes  : {list(causes_to_run.keys())}")
    print(f"  States  : {len(states_to_run)}")
    print(f"  Total   : {total}  |  Already done: {already}  |  To run: {len(todo)}")
    print(f"  Output  : {abs_output}")
    print(f"  Rate    : {args.rate_limit}s between queries")
    if len(todo) > 0:
        est_h = len(todo) * args.rate_limit / 3600
        print(f"  Est. time: ~{est_h:.1f} hours")
    print()

    if not todo:
        print("  Nothing to do — all pairs already scraped.")
        return

    driver = setup_driver(abs_output, headless=not args.no_headless)
    ok_list    = []
    nodata_list = []
    error_list  = []

    try:
        for idx, (fips, state_name, cause_key, cause_info) in enumerate(todo, 1):
            print(f"\n[{idx}/{len(todo)}]", flush=True)
            result = scrape_state_cause(
                driver, fips, state_name, cause_key, cause_info,
                QUERY_YEARS, abs_output
            )

            if result == "ok":
                ok_list.append(f"{state_name}/{cause_key}")
            elif result == "nodata":
                nodata_list.append(f"{state_name}/{cause_key}")
                # Write NODATA marker so we don't retry
                marker = os.path.join(abs_output,
                    f"mortality_{fips}_{state_name}_{cause_key}.NODATA")
                open(marker, "w").close()
            else:
                error_list.append(f"{state_name}/{cause_key}")

            if idx < len(todo):
                print(f"  ⏳ Rate limit: {args.rate_limit}s …", flush=True)
                time.sleep(args.rate_limit)

    finally:
        driver.quit()

    print("\n" + "="*70)
    print("  SCRAPING COMPLETE")
    print("="*70)
    print(f"  ✓ Downloaded : {len(ok_list)}")
    print(f"  ○ No data   : {len(nodata_list)}")
    print(f"  ✗ Errors    : {len(error_list)}")
    if error_list:
        print(f"\n  Errors (re-run with --states {' '.join(f.split('/')[0][:2] for f in error_list[:5])}):")
        for e in error_list[:10]:
            print(f"    ✗ {e}")
    print(f"\n  Output: {abs_output}")
    print("  Next: Rscript /tmp/migrate_cdc_wonder_causes_to_cache.R")


if __name__ == "__main__":
    main()
