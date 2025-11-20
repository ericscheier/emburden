#!/usr/bin/env bash
#
# End-to-End Zenodo Dataset Regeneration and Deployment
#
# This script automates the entire workflow:
#   1. Regenerate datasets with validation and auto-healing
#   2. Retry failed datasets with cache clearing
#   3. Verify all 4 datasets are complete
#   4. Update MD5 checksums in R/zenodo.R
#   5. Create git commit
#   6. Upload to Zenodo
#   7. Push to GitHub with tags
#
# Usage:
#   bash .dev/regenerate-and-deploy-zenodo.sh [--force-download] [--skip-upload]
#
# Options:
#   --force-download  Clear all caches and re-download from OpenEI
#   --skip-upload     Skip Zenodo upload (just regenerate and update code)
#   --retry-only      Only retry failed datasets, don't regenerate successful ones
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
FORCE_DOWNLOAD=false
SKIP_UPLOAD=false
RETRY_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --force-download)
      FORCE_DOWNLOAD=true
      shift
      ;;
    --skip-upload)
      SKIP_UPLOAD=true
      shift
      ;;
    --retry-only)
      RETRY_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--force-download] [--skip-upload] [--retry-only]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}================================================================================"
echo "  End-to-End Zenodo Dataset Regeneration and Deployment"
echo -e "================================================================================${NC}"
echo ""
echo "Configuration:"
echo "  Force download: $FORCE_DOWNLOAD"
echo "  Skip upload: $SKIP_UPLOAD"
echo "  Retry only: $RETRY_ONLY"
echo ""

# Directories
ZENODO_DIR="zenodo-upload-nationwide"
NATIONWIDE_DIR="$ZENODO_DIR/nationwide"
LOG_FILE="regeneration-deploy.log"

# Expected datasets
EXPECTED_DATASETS=(
  "lead_ami_cohorts_2022_us.csv.gz"
  "lead_fpl_cohorts_2022_us.csv.gz"
  "lead_ami_cohorts_2018_us.csv.gz"
  "lead_fpl_cohorts_2018_us.csv.gz"
)

# Track failures
FAILED_DATASETS=()

################################################################################
# Step 1: Initial Regeneration
################################################################################

echo -e "${BLUE}================================================================================"
echo "  Step 1: Generate Nationwide Datasets"
echo -e "================================================================================${NC}"
echo ""

if [ "$RETRY_ONLY" = false ]; then
  # Full regeneration
  REGEN_FLAGS="--nationwide-only"

  if [ "$FORCE_DOWNLOAD" = true ]; then
    echo "⚠️  Force download enabled - clearing all caches..."
    Rscript -e "emburden::clear_all_cache(confirm = TRUE, verbose = TRUE)"
    REGEN_FLAGS="$REGEN_FLAGS --force-download"
  fi

  echo "Running: Rscript .dev/prepare-zenodo-data-nationwide.R $REGEN_FLAGS"
  Rscript .dev/prepare-zenodo-data-nationwide.R $REGEN_FLAGS 2>&1 | tee "$LOG_FILE"
else
  echo "⏭️  Skipping initial regeneration (retry-only mode)"
fi

################################################################################
# Step 2: Check Which Datasets Failed
################################################################################

echo ""
echo -e "${BLUE}================================================================================"
echo "  Step 2: Validate Generated Datasets"
echo -e "================================================================================${NC}"
echo ""

if [ ! -d "$NATIONWIDE_DIR" ]; then
  echo -e "${RED}❌ ERROR: Nationwide directory not found: $NATIONWIDE_DIR${NC}"
  exit 1
fi

SUCCESSFUL_DATASETS=()
FAILED_DATASETS=()

for dataset in "${EXPECTED_DATASETS[@]}"; do
  file_path="$NATIONWIDE_DIR/$dataset"

  if [ -f "$file_path" ]; then
    # Check file size (should be >1MB for valid data)
    size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0")
    size_mb=$((size / 1024 / 1024))

    if [ "$size_mb" -gt 1 ]; then
      echo -e "  ✅ ${GREEN}$dataset${NC} (${size_mb}MB)"
      SUCCESSFUL_DATASETS+=("$dataset")
    else
      echo -e "  ❌ ${RED}$dataset${NC} (${size_mb}MB - TOO SMALL)"
      FAILED_DATASETS+=("$dataset")
    fi
  else
    echo -e "  ❌ ${RED}$dataset${NC} (MISSING)"
    FAILED_DATASETS+=("$dataset")
  fi
done

echo ""
echo "Summary:"
echo "  ✅ Successful: ${#SUCCESSFUL_DATASETS[@]}/4"
echo "  ❌ Failed: ${#FAILED_DATASETS[@]}/4"

################################################################################
# Step 3: Retry Failed Datasets with Cache Clearing
################################################################################

if [ ${#FAILED_DATASETS[@]} -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}================================================================================"
  echo "  Step 3: Retry Failed Datasets (Auto-Healing)"
  echo -e "================================================================================${NC}"
  echo ""

  for failed_dataset in "${FAILED_DATASETS[@]}"; do
    echo ""
    echo -e "${YELLOW}⚠️  Retrying: $failed_dataset${NC}"

    # Extract dataset and vintage from filename
    # Format: lead_{dataset}_cohorts_{vintage}_us.csv.gz
    dataset_name=$(echo "$failed_dataset" | sed -E 's/lead_(.*)_cohorts_.*_us\.csv\.gz/\1/')
    vintage=$(echo "$failed_dataset" | sed -E 's/lead_.*_cohorts_(....)_us\.csv\.gz/\1/')

    echo "  Dataset: $dataset_name"
    echo "  Vintage: $vintage"
    echo ""

    # Clear corrupt cache for this specific dataset
    echo "  Clearing corrupt cache..."
    Rscript -e "emburden::clear_dataset_cache('$dataset_name', '$vintage', verbose = TRUE)"

    # Re-run just this dataset
    echo "  Regenerating..."
    Rscript -e "
      library(emburden)
      library(readr)
      library(dplyr)

      # Load with self-healing
      data <- load_cohort_data(
        dataset = '$dataset_name',
        vintage = '$vintage',
        states = NULL,  # All states
        verbose = TRUE
      )

      # Validate
      if (is.null(data) || nrow(data) == 0) {
        stop('Failed to load data after cache clear')
      }

      # Check states
      if ('state_abbr' %in% names(data)) {
        n_states <- length(unique(data\$state_abbr))
        cat('States found:', n_states, '\\n')
        if (n_states < 51) {
          stop('Still missing states after retry: ', 51 - n_states)
        }
      }

      # Save to Zenodo directory
      output_dir <- 'zenodo-upload-nationwide/nationwide'
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
      }

      output_file <- file.path(output_dir, '$failed_dataset')
      output_csv <- sub('\\\\.gz\$', '', output_file)

      # Write and compress
      write_csv(data, output_csv)
      system2('gzip', args = c('-9', '-f', output_csv))

      cat('✅ Successfully regenerated:', '$failed_dataset', '\\n')
    " 2>&1 | tee -a "$LOG_FILE"

    # Check if successful
    if [ -f "$NATIONWIDE_DIR/$failed_dataset" ]; then
      size=$(stat -c%s "$NATIONWIDE_DIR/$failed_dataset" 2>/dev/null || stat -f%z "$NATIONWIDE_DIR/$failed_dataset" 2>/dev/null || echo "0")
      size_mb=$((size / 1024 / 1024))

      if [ "$size_mb" -gt 1 ]; then
        echo -e "  ${GREEN}✅ Retry successful!${NC} (${size_mb}MB)"
        # Remove from failed list
        FAILED_DATASETS=("${FAILED_DATASETS[@]/$failed_dataset}")
        SUCCESSFUL_DATASETS+=("$failed_dataset")
      else
        echo -e "  ${RED}❌ Retry failed${NC} (still too small: ${size_mb}MB)"
      fi
    else
      echo -e "  ${RED}❌ Retry failed${NC} (file not created)"
    fi
  done
fi

################################################################################
# Step 4: Final Validation
################################################################################

echo ""
echo -e "${BLUE}================================================================================"
echo "  Step 4: Final Validation"
echo -e "================================================================================${NC}"
echo ""

# Re-count successful datasets
SUCCESSFUL_COUNT=0
for dataset in "${EXPECTED_DATASETS[@]}"; do
  file_path="$NATIONWIDE_DIR/$dataset"
  if [ -f "$file_path" ]; then
    size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null || echo "0")
    size_mb=$((size / 1024 / 1024))
    if [ "$size_mb" -gt 1 ]; then
      ((SUCCESSFUL_COUNT++)) || true
    fi
  fi
done

if [ "$SUCCESSFUL_COUNT" -eq 4 ]; then
  echo -e "${GREEN}✅ ALL 4 DATASETS SUCCESSFULLY GENERATED!${NC}"
else
  echo -e "${RED}❌ ONLY $SUCCESSFUL_COUNT/4 DATASETS GENERATED${NC}"
  echo ""
  echo "Failed datasets still missing. Manual intervention required."
  echo "Check log file: $LOG_FILE"
  exit 1
fi

################################################################################
# Step 5: Update MD5 Checksums in R/zenodo.R
################################################################################

echo ""
echo -e "${BLUE}================================================================================"
echo "  Step 5: Update MD5 Checksums in R/zenodo.R"
echo -e "================================================================================${NC}"
echo ""

echo "Calculating new MD5 checksums..."
declare -A MD5_MAP

for dataset in "${EXPECTED_DATASETS[@]}"; do
  file_path="$NATIONWIDE_DIR/$dataset"
  if [ -f "$file_path" ]; then
    md5=$(md5sum "$file_path" | awk '{print $1}')
    MD5_MAP["$dataset"]="$md5"
    echo "  $dataset: $md5"
  fi
done

# Update R/zenodo.R with new checksums
echo ""
echo "Updating R/zenodo.R..."

# Create backup
cp R/zenodo.R R/zenodo.R.bak

# Use R to update checksums (more reliable than sed)
Rscript -e "
  # Read file
  lines <- readLines('R/zenodo.R')

  # Update each checksum
  checksums <- list(
    'lead_ami_cohorts_2022_us.csv.gz' = '${MD5_MAP[lead_ami_cohorts_2022_us.csv.gz]}',
    'lead_fpl_cohorts_2022_us.csv.gz' = '${MD5_MAP[lead_fpl_cohorts_2022_us.csv.gz]}',
    'lead_ami_cohorts_2018_us.csv.gz' = '${MD5_MAP[lead_ami_cohorts_2018_us.csv.gz]}',
    'lead_fpl_cohorts_2018_us.csv.gz' = '${MD5_MAP[lead_fpl_cohorts_2018_us.csv.gz]}'
  )

  for (filename in names(checksums)) {
    pattern <- paste0('\"', filename, '\" = \"[a-f0-9]{32}\"')
    replacement <- paste0('\"', filename, '\" = \"', checksums[[filename]], '\"')

    for (i in seq_along(lines)) {
      lines[i] <- gsub(pattern, replacement, lines[i])
    }
  }

  writeLines(lines, 'R/zenodo.R')
  cat('✅ Updated MD5 checksums in R/zenodo.R\\n')
"

echo -e "${GREEN}✅ MD5 checksums updated${NC}"

################################################################################
# Step 6: Git Commit
################################################################################

echo ""
echo -e "${BLUE}================================================================================"
echo "  Step 6: Git Commit"
echo -e "================================================================================${NC}"
echo ""

if git diff --quiet R/zenodo.R; then
  echo "No changes to R/zenodo.R (checksums already up to date)"
else
  echo "Committing updated checksums..."
  git add R/zenodo.R
  git commit -m "chore: Update Zenodo dataset MD5 checksums

- Regenerated all 4 nationwide datasets
- Updated MD5 checksums in R/zenodo.R
- All datasets validated with 51 states and detailed income brackets

Datasets updated:
- lead_ami_cohorts_2022_us.csv.gz
- lead_fpl_cohorts_2022_us.csv.gz
- lead_ami_cohorts_2018_us.csv.gz
- lead_fpl_cohorts_2018_us.csv.gz"

  echo -e "${GREEN}✅ Git commit created${NC}"
fi

################################################################################
# Step 7: Upload to Zenodo
################################################################################

if [ "$SKIP_UPLOAD" = false ]; then
  echo ""
  echo -e "${BLUE}================================================================================"
  echo "  Step 7: Upload to Zenodo"
  echo -e "================================================================================${NC}"
  echo ""

  echo "Uploading datasets to Zenodo..."
  bash .dev/upload-to-zenodo-nationwide.sh 2>&1 | tee -a "$LOG_FILE"

  echo -e "${GREEN}✅ Zenodo upload complete${NC}"
else
  echo ""
  echo -e "${YELLOW}⏭️  Skipping Zenodo upload (--skip-upload flag)${NC}"
  echo ""
  echo "To upload manually:"
  echo "  bash .dev/upload-to-zenodo-nationwide.sh"
fi

################################################################################
# Step 8: Push to GitHub
################################################################################

echo ""
echo -e "${BLUE}================================================================================"
echo "  Step 8: Push to GitHub"
echo -e "================================================================================${NC}"
echo ""

if [ "$SKIP_UPLOAD" = false ]; then
  echo "Pushing to GitHub..."
  git push --follow-tags
  echo -e "${GREEN}✅ Pushed to GitHub${NC}"
else
  echo -e "${YELLOW}⏭️  Skipping GitHub push (run manually: git push --follow-tags)${NC}"
fi

################################################################################
# Summary
################################################################################

echo ""
echo -e "${GREEN}================================================================================"
echo "  ✅ DEPLOYMENT COMPLETE!"
echo -e "================================================================================${NC}"
echo ""
echo "Summary:"
echo "  ✅ Generated: $SUCCESSFUL_COUNT/4 datasets"
echo "  ✅ Updated: R/zenodo.R MD5 checksums"
echo "  ✅ Committed: Changes to git"
if [ "$SKIP_UPLOAD" = false ]; then
  echo "  ✅ Uploaded: Datasets to Zenodo"
  echo "  ✅ Pushed: Changes to GitHub"
else
  echo "  ⏭️  Skipped: Zenodo upload and GitHub push"
fi
echo ""
echo "Log file: $LOG_FILE"
echo ""
echo "Next steps:"
echo "  1. Verify datasets on Zenodo"
echo "  2. Test download: emburden::load_cohort_data('ami', '2022')"
echo "  3. Submit to CRAN if ready"
echo ""
