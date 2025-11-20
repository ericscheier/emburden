#!/bin/bash
# upload-to-zenodo-nationwide.sh
# Automated Zenodo upload for NATIONWIDE datasets using REST API
#
# Usage: ./upload-to-zenodo-nationwide.sh [--sandbox]
#
# Environment variables required:
#   ZENODO_TOKEN - Your Zenodo personal access token
#
# Optional:
#   --sandbox - Upload to sandbox.zenodo.org instead of production

set -e  # Exit on error

# Configuration
USE_SANDBOX=false
if [[ "$1" == "--sandbox" ]]; then
    USE_SANDBOX=true
    ZENODO_URL="https://sandbox.zenodo.org/api"
    echo "Using SANDBOX environment (sandbox.zenodo.org)"
else
    ZENODO_URL="https://zenodo.org/api"
    echo "Using PRODUCTION environment (zenodo.org)"
fi

# Check for API token
if [ -z "$ZENODO_TOKEN" ]; then
    echo ""
    echo "ERROR: ZENODO_TOKEN environment variable not set"
    echo ""
    echo "To obtain a token:"
    if $USE_SANDBOX; then
        echo "1. Go to https://sandbox.zenodo.org/account/settings/applications/tokens/new/"
    else
        echo "1. Go to https://zenodo.org/account/settings/applications/tokens/new/"
    fi
    echo "2. Create a new token with 'deposit:write' and 'deposit:actions' scopes"
    echo "3. Export it: export ZENODO_TOKEN='your-token-here'"
    echo ""
    exit 1
fi

# Directory containing files to upload
UPLOAD_DIR="zenodo-upload-nationwide/nationwide"
if [ ! -d "$UPLOAD_DIR" ]; then
    echo "ERROR: Upload directory not found: $UPLOAD_DIR"
    exit 1
fi

echo ""
echo "========================================"
echo "  Zenodo Automated Upload (NATIONWIDE)"
echo "========================================"
echo ""
echo "Upload directory: $UPLOAD_DIR"
echo ""

# Validate checksums before uploading
echo "Validating MD5 checksums..."
if ! Rscript .dev/validate-zenodo-checksums.R; then
    echo ""
    echo "❌ ABORT: Checksum validation failed!"
    echo "   Fix the mismatches in R/zenodo.R before uploading."
    exit 1
fi
echo ""

# Files to upload
# NOTE: Arizona 2018 data has non-standard filename handled in R code
FILES=(
    "lead_ami_cohorts_2022_us.csv.gz"
    "lead_fpl_cohorts_2022_us.csv.gz"
    "lead_ami_cohorts_2018_us.csv.gz"
    "lead_fpl_cohorts_2018_us.csv.gz"
)

# Also include checksums from parent directory
CHECKSUMS_FILE="zenodo-upload-nationwide/checksums.txt"

# Verify all files exist
echo "Verifying files..."
for file in "${FILES[@]}"; do
    if [ ! -f "$UPLOAD_DIR/$file" ]; then
        echo "ERROR: File not found: $UPLOAD_DIR/$file"
        exit 1
    fi
    size=$(ls -lh "$UPLOAD_DIR/$file" | awk '{print $5}')
    echo "  ✓ $file ($size)"
done

if [ ! -f "$CHECKSUMS_FILE" ]; then
    echo "ERROR: Checksums file not found: $CHECKSUMS_FILE"
    exit 1
fi
echo "  ✓ checksums.txt"
echo ""

# Step 1: Create a new deposition
echo "Step 1: Creating new deposition..."
response=$(curl -s -X POST -d '{}' \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZENODO_TOKEN" \
    "$ZENODO_URL/deposit/depositions")

# Extract deposition ID and bucket URL
deposition_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
bucket_url=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['links']['bucket'])")

if [ -z "$deposition_id" ] || [ "$deposition_id" == "null" ]; then
    echo "ERROR: Failed to create deposition"
    echo "Response: $response"
    exit 1
fi

echo "✓ Deposition created: ID $deposition_id"
echo "  Bucket URL: $bucket_url"
echo ""

# Step 2: Upload files
echo "Step 2: Uploading files..."
for file in "${FILES[@]}"; do
    echo "  Uploading: $file"

    upload_response=$(curl -s --progress-bar \
        -H "Authorization: Bearer $ZENODO_TOKEN" \
        -H "Content-Type: application/octet-stream" \
        --upload-file "$UPLOAD_DIR/$file" \
        "$bucket_url/$file")

    upload_status=$(echo "$upload_response" | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if 'key' in d else 'FAILED')" 2>/dev/null || echo "FAILED")

    if [ "$upload_status" == "OK" ]; then
        echo "    ✓ Uploaded successfully"
    else
        echo "    ERROR: Upload failed"
        echo "    Response: $upload_response"
        exit 1
    fi
done

# Upload checksums file
echo "  Uploading: checksums.txt"
upload_response=$(curl -s --progress-bar \
    -H "Authorization: Bearer $ZENODO_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --upload-file "$CHECKSUMS_FILE" \
    "$bucket_url/checksums.txt")

upload_status=$(echo "$upload_response" | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if 'key' in d else 'FAILED')" 2>/dev/null || echo "FAILED")

if [ "$upload_status" == "OK" ]; then
    echo "    ✓ Uploaded successfully"
else
    echo "    ERROR: Upload failed"
    echo "    Response: $upload_response"
    exit 1
fi
echo ""

# Step 3: Add metadata
echo "Step 3: Adding metadata..."

# Prepare metadata JSON
metadata=$(cat <<'EOF'
{
    "metadata": {
        "title": "emburden: Processed Energy Burden Datasets (US Nationwide)",
        "upload_type": "dataset",
        "description": "PROCESSED, analysis-ready household energy burden datasets from the DOE Low-Income Energy Affordability Data (LEAD) Tool, formatted for the emburden R package.\n\n<strong>Scope:</strong> All 51 US states and territories (50 states + DC)\n\n<strong>IMPORTANT:</strong> These are PRE-PROCESSED datasets, not raw OpenEI data. They have been:\n<ul>\n<li>Aggregated by census tract + income bracket</li>\n<li>Enriched with computed energy burden metrics (EROI, NER, DEAR)</li>\n<li>Standardized for immediate analysis</li>\n<li>Quality-checked and validated</li>\n</ul>\n\nThis repository provides census tract-level data on household energy burden for the entire United States, covering ~73,000 census tracts. Data includes both Area Median Income (AMI) and Federal Poverty Line (FPL) cohort analyses for 2018 and 2022 vintages.\n\n<h2>Files Included:</h2>\n<ul>\n<li>lead_ami_cohorts_2022_us.csv.gz: 2022 AMI cohort data (701,490 records, 148 MB)</li>\n<li>lead_fpl_cohorts_2022_us.csv.gz: 2022 FPL cohort data (588,163 records, 52 MB)</li>\n<li>lead_ami_cohorts_2018_us.csv.gz: 2018 AMI cohort data (530,500 records, 54 MB)</li>\n<li>lead_fpl_cohorts_2018_us.csv.gz: 2018 FPL cohort data (514,893 records, 53 MB)</li>\n<li>checksums.txt: MD5 checksums for verification</li>\n</ul>\n\nTotal size: 307 MB compressed\n\n<h2>Data Processing</h2>\n<ul>\n<li><strong>Source:</strong> Raw LEAD Tool data from OpenEI</li>\n<li><strong>Processing:</strong> emburden R package v0.4.8 data pipeline</li>\n<li><strong>Format:</strong> CSV (aggregated tract-level cohorts with computed metrics)</li>\n<li><strong>Ready for:</strong> Immediate analysis, no additional processing required</li>\n</ul>\n\n<h2>Coverage</h2>\n<ul>\n<li>States: All 51 (50 states + DC, excludes PR)</li>\n<li>Census Tracts: ~73,000 nationwide</li>\n<li>Total Records: 2.3+ million cohort observations</li>\n<li>Income Brackets: 4-6 per dataset/vintage</li>\n</ul>\n\n<h2>Data Sources</h2>\nOriginal raw data from:\n<ul>\n<li>DOE LEAD Tool 2022: https://data.openei.org/submissions/6219</li>\n<li>DOE LEAD Tool 2018: https://data.openei.org/submissions/573</li>\n</ul>\n\nProcessed using: emburden R package v0.4.8 (https://github.com/ScheierVentures/emburden)\n\n<h2>Citation</h2>\nWhen using this data, please cite:\n<ol>\n<li>This Zenodo repository (DOI provided)</li>\n<li>The emburden R package v0.4.8</li>\n<li>The original DOE LEAD Tool publications</li>\n</ol>\n\n<h2>License</h2>\nCC-BY-4.0 (same as source data)",
        "creators": [
            {
                "name": "Scheier, Eric",
                "affiliation": "Emergi Foundation, UNC Chapel Hill",
                "orcid": "0000-0001-9849-9089"
            }
        ],
        "keywords": [
            "energy burden",
            "energy poverty",
            "household energy",
            "census tracts",
            "LEAD Tool",
            "R package",
            "emburden",
            "nationwide",
            "United States"
        ],
        "license": "cc-by-4.0",
        "access_right": "open",
        "related_identifiers": [
            {
                "identifier": "https://github.com/ScheierVentures/emburden",
                "relation": "isSupplementTo",
                "scheme": "url"
            },
            {
                "identifier": "https://data.openei.org/submissions/6219",
                "relation": "isDerivedFrom",
                "scheme": "url"
            },
            {
                "identifier": "https://data.openei.org/submissions/573",
                "relation": "isDerivedFrom",
                "scheme": "url"
            }
        ]
    }
}
EOF
)

metadata_response=$(curl -s -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ZENODO_TOKEN" \
    -d "$metadata" \
    "$ZENODO_URL/deposit/depositions/$deposition_id")

metadata_status=$(echo "$metadata_response" | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if 'metadata' in d else 'FAILED')" 2>/dev/null || echo "FAILED")

if [ "$metadata_status" == "OK" ]; then
    echo "✓ Metadata added successfully"
else
    echo "ERROR: Failed to add metadata"
    echo "Response: $metadata_response"
    exit 1
fi
echo ""

# Step 4: Publish
echo "Step 4: Publishing deposition..."
echo ""
echo "WARNING: This will publish the deposition and make it publicly available."
echo "Once published, it CANNOT be deleted (only new versions can be created)."
echo ""
read -p "Proceed with publication? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo ""
    echo "Publication cancelled."
    echo ""
    echo "Deposition ID $deposition_id is saved as DRAFT."
    if $USE_SANDBOX; then
        echo "View at: https://sandbox.zenodo.org/deposit/$deposition_id"
    else
        echo "View at: https://zenodo.org/deposit/$deposition_id"
    fi
    echo ""
    echo "To publish later, run:"
    echo "  curl -X POST -H \"Authorization: Bearer \$ZENODO_TOKEN\" \\"
    echo "    $ZENODO_URL/deposit/depositions/$deposition_id/actions/publish"
    echo ""
    exit 0
fi

publish_response=$(curl -s -X POST -d '{}' \
    -H "Authorization: Bearer $ZENODO_TOKEN" \
    "$ZENODO_URL/deposit/depositions/$deposition_id/actions/publish")

# Extract DOIs and URLs
concept_doi=$(echo "$publish_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('conceptdoi', ''))" 2>/dev/null || echo "")
version_doi=$(echo "$publish_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('doi', ''))" 2>/dev/null || echo "")
record_id=$(echo "$publish_response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('record_id', ''))" 2>/dev/null || echo "")

if [ -z "$version_doi" ] || [ "$version_doi" == "null" ]; then
    echo "ERROR: Publication failed"
    echo "Response: $publish_response"
    exit 1
fi

echo "✓ Publication successful!"
echo ""
echo "========================================"
echo "  Upload Complete!"
echo "========================================"
echo ""
echo "Concept DOI (always latest): $concept_doi"
echo "Version DOI (this version):  $version_doi"
echo "Record ID:                   $record_id"
echo ""
if $USE_SANDBOX; then
    record_url="https://sandbox.zenodo.org/records/$record_id"
else
    record_url="https://zenodo.org/records/$record_id"
fi
echo "View at: $record_url"
echo ""

# Generate file URLs and save configuration
echo "File download URLs:"
echo ""

config_file="zenodo-upload-nationwide/zenodo-config-nationwide.txt"
cat > "$config_file" << CONF_EOF
# Zenodo Configuration (NATIONWIDE)
# Generated: $(date)
# Environment: $(if $USE_SANDBOX; then echo "SANDBOX"; else echo "PRODUCTION"; fi)

CONCEPT_DOI="$concept_doi"
VERSION_DOI="$version_doi"
RECORD_ID="$record_id"
RECORD_URL="$record_url"

# File URLs (for R/zenodo.R configuration)
CONF_EOF

ALL_FILES=("${FILES[@]}" "checksums.txt")
for file in "${ALL_FILES[@]}"; do
    if $USE_SANDBOX; then
        file_url="https://sandbox.zenodo.org/records/$record_id/files/$file"
    else
        file_url="https://zenodo.org/records/$record_id/files/$file"
    fi
    echo "  - $file"
    echo "    $file_url"
    echo ""
    echo "FILE_$file=\"$file_url\"" >> "$config_file"
done

echo "Configuration saved to: $config_file"
echo ""
echo "Next steps:"
echo "  1. Run: Rscript .dev/update-zenodo-config.R to auto-update R/zenodo.R"
echo "  2. Test Zenodo downloads"
echo "  3. Create new release with working Zenodo integration"
echo ""
