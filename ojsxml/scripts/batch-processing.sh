#!/bin/bash
################################################################################
# Batch Processing Script for OJS XML Generation
# 
# This script can process:
# - ZIP files in tmp/ directory (default): Extracts and processes each
# - Existing folders in tmp/ (with --process-folders): Processes directly
#
# Processing steps:
# 1. Extract ZIP files OR scan existing folders
# 2. Run XML generation from within each folder
# 3. Generate detailed logs for each operation
# 4. Create errors.md file if any errors occur
# 5. Validate generated XML files against schema
#
# Usage: ./batch-processing.sh [options]
#
# Options:
#   --dry-run          Show what would be processed without actually doing it
#   --skip-validation  Skip XML schema validation
#   --clean            Remove processed folders after processing
#   --process-folders  Process existing unzipped folders instead of ZIP files
#   --help             Show this help message
################################################################################

set -o pipefail  # Exit on pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
DRY_RUN=false
SKIP_VALIDATION=false
CLEAN_AFTER=false
PROCESS_FOLDERS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-validation)
      SKIP_VALIDATION=true
      shift
      ;;
    --clean)
      CLEAN_AFTER=true
      shift
      ;;
    --process-folders)
      PROCESS_FOLDERS=true
      shift
      ;;
    --help|-h)
      echo "Batch Processing Script for OJS XML Generation"
      echo ""
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --dry-run          Show what would be processed without actually doing it"
      echo "  --skip-validation  Skip XML schema validation"
      echo "  --clean            Remove extracted folders after successful processing"
      echo "  --process-folders  Process existing unzipped folders instead of ZIP files"
      echo "  --help, -h         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                        # Process all ZIP files in tmp/"
      echo "  $0 --process-folders      # Process existing folders in tmp/"
      echo "  $0 --dry-run              # Preview what would be processed"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_PATH="$(cd "$PROJECT_ROOT/.." && pwd)"
TMP_DIR="$PROJECT_ROOT/tmp"
OUTPUT_DIR="$PROJECT_ROOT/docroot/output"
SCHEMA_FILE="$PROJECT_ROOT/schema/schema_3_5.xsd"
PROCESS_SCRIPT="$SCRIPT_DIR/process-issue.sh"

# Global errors file
ERRORS_FILE="$TMP_DIR/errors.md"
BATCH_LOG="$TMP_DIR/batch_processing_$(date +%Y%m%d_%H%M%S).log"

# Initialize/clear errors file
if [ "$DRY_RUN" = false ]; then
  echo "# Batch Processing Errors" > "$ERRORS_FILE"
  echo "" >> "$ERRORS_FILE"
  echo "**Generated:** $(date)" >> "$ERRORS_FILE"
  echo "" >> "$ERRORS_FILE"
fi

# Function to log messages
log_message() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case $level in
    ERROR)
      echo -e "${RED}[ERROR]${NC} $message" | tee -a "$BATCH_LOG"
      ;;
    SUCCESS)
      echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$BATCH_LOG"
      ;;
    WARNING)
      echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$BATCH_LOG"
      ;;
    INFO)
      echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$BATCH_LOG"
      ;;
    *)
      echo "[$timestamp] $message" | tee -a "$BATCH_LOG"
      ;;
  esac
}

# Function to add error to errors.md
add_error() {
  local zip_name=$1
  local error_message=$2
  local error_details=$3
  
  {
    echo "## Error in: $zip_name"
    echo ""
    echo "**Time:** $(date)"
    echo ""
    echo "**Error:** $error_message"
    echo ""
    if [ -n "$error_details" ]; then
      echo "**Details:**"
      echo '```'
      echo "$error_details"
      echo '```'
      echo ""
    fi
    echo "---"
    echo ""
  } >> "$ERRORS_FILE"
}

# Function to compress large PDFs using Ghostscript
compress_large_pdfs() {
  local folder_path=$1
  local log_file=$2
  local size_threshold=$((5 * 1024 * 1024))  # 5MB in bytes
  local compressed_count=0
  
  log_message INFO "Checking for PDFs larger than 5MB..."
  echo "" >> "$log_file"
  echo "=== PDF COMPRESSION ===" >> "$log_file"
  echo "Folder: $folder_path" >> "$log_file"
  echo "Size threshold: 5MB" >> "$log_file"
  echo "Target resolution: 120 dpi" >> "$log_file"
  echo "" >> "$log_file"
  
  # Check if ghostscript is installed
  if ! command -v gs &> /dev/null; then
    log_message WARNING "Ghostscript not installed, skipping PDF compression"
    echo "⚠ Ghostscript not found - PDF compression skipped" >> "$log_file"
    echo "" >> "$log_file"
    return 0
  fi
  
  # Find all PDF files recursively
  while IFS= read -r -d '' pdf_file; do
    if [ -f "$pdf_file" ]; then
      file_size=$(stat -c%s "$pdf_file" 2>/dev/null || stat -f%z "$pdf_file" 2>/dev/null)
      
      if [ "$file_size" -gt "$size_threshold" ]; then
        pdf_basename=$(basename "$pdf_file")
        size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc)
        
        log_message INFO "Compressing: $pdf_basename ($size_mb MB)"
        echo "File: $pdf_file" >> "$log_file"
        echo "Original size: $size_mb MB" >> "$log_file"
        
        # Create temporary output file
        temp_pdf="${pdf_file%.pdf}_compressed_temp.pdf"
        
        # Run Ghostscript compression to 120 dpi
        gs_output=$(gs -sDEVICE=pdfwrite \
          -dCompatibilityLevel=1.4 \
          -dDownsampleColorImages=true \
          -dDownsampleGrayImages=true \
          -dDownsampleMonoImages=true \
          -dColorImageResolution=120 \
          -dGrayImageResolution=120 \
          -dMonoImageResolution=120 \
          -dNOPAUSE \
          -dQUIET \
          -dBATCH \
          -sOutputFile="$temp_pdf" \
          "$pdf_file" 2>&1)
        
        gs_result=$?
        
        if [ $gs_result -eq 0 ] && [ -f "$temp_pdf" ]; then
          # Check if compression was successful and file is smaller
          new_size=$(stat -c%s "$temp_pdf" 2>/dev/null || stat -f%z "$temp_pdf" 2>/dev/null)
          new_size_mb=$(echo "scale=2; $new_size / 1024 / 1024" | bc)
          
          if [ "$new_size" -lt "$file_size" ]; then
            # Replace original with compressed version
            mv "$temp_pdf" "$pdf_file"
            compression_ratio=$(echo "scale=1; 100 - ($new_size * 100 / $file_size)" | bc)
            
            log_message SUCCESS "Compressed $pdf_basename: $size_mb MB → $new_size_mb MB (${compression_ratio}% reduction)"
            echo "New size: $new_size_mb MB" >> "$log_file"
            echo "Compression: ${compression_ratio}% reduction" >> "$log_file"
            echo "✓ Compression successful" >> "$log_file"
            ((compressed_count++))
          else
            # Compressed file is not smaller, keep original
            rm -f "$temp_pdf"
            log_message WARNING "Compressed file not smaller for $pdf_basename, keeping original"
            echo "⚠ Compressed file not smaller, keeping original" >> "$log_file"
          fi
        else
          log_message ERROR "Ghostscript failed for $pdf_basename"
          echo "✗ Ghostscript compression failed" >> "$log_file"
          echo "Error output: $gs_output" >> "$log_file"
          rm -f "$temp_pdf"
        fi
        
        echo "" >> "$log_file"
      fi
    fi
  done < <(find "$folder_path" -type f -name "*.pdf" -print0)
  
  if [ $compressed_count -gt 0 ]; then
    log_message SUCCESS "Compressed $compressed_count PDF(s)"
    echo "✓ Total PDFs compressed: $compressed_count" >> "$log_file"
  else
    log_message INFO "No PDFs required compression"
    echo "No PDFs larger than 5MB found" >> "$log_file"
  fi
  
  echo "" >> "$log_file"
  return 0
}

# Function to validate XML against schema
validate_xml() {
  local xml_file=$1
  local log_file=$2
  
  if [ ! -f "$xml_file" ]; then
    log_message WARNING "XML file not found: $xml_file"
    echo "XML file not found: $xml_file" >> "$log_file"
    return 1
  fi
  
  if [ ! -f "$SCHEMA_FILE" ]; then
    log_message WARNING "Schema file not found: $SCHEMA_FILE"
    echo "Schema file not found: $SCHEMA_FILE" >> "$log_file"
    return 1
  fi
  
  log_message INFO "Validating XML against schema..."
  echo "" >> "$log_file"
  echo "=== XML VALIDATION ===" >> "$log_file"
  echo "XML File: $xml_file" >> "$log_file"
  echo "Schema: $SCHEMA_FILE" >> "$log_file"
  echo "" >> "$log_file"
  
  # Use xmllint for validation
  validation_output=$(xmllint --noout --schema "$SCHEMA_FILE" "$xml_file" 2>&1)
  validation_result=$?
  
  echo "$validation_output" >> "$log_file"
  echo "" >> "$log_file"
  
  if [ $validation_result -eq 0 ]; then
    log_message SUCCESS "XML validation passed"
    echo "✓ XML validation PASSED" >> "$log_file"
    return 0
  else
    log_message ERROR "XML validation FAILED"
    echo "✗ XML validation FAILED" >> "$log_file"
    echo "" >> "$log_file"
    echo "Validation errors:" >> "$log_file"
    echo "$validation_output" >> "$log_file"
    return 1
  fi
}

# Function to process a single ZIP file
process_zip() {
  local zip_file=$1
  local zip_basename=$(basename "$zip_file" .zip)
  local extract_dir="$TMP_DIR/$zip_basename"
  local log_file="$extract_dir/${zip_basename}_processing.log"
  
  log_message INFO "========================================="
  log_message INFO "Processing: $zip_basename"
  log_message INFO "========================================="
  
  if [ "$DRY_RUN" = true ]; then
    log_message INFO "[DRY RUN] Would extract to: $extract_dir"
    if [ -d "$extract_dir" ]; then
      log_message WARNING "[DRY RUN] Directory already exists and would be SKIPPED"
    fi
    return 0
  fi
  
  # Check if extraction directory already exists
  if [ -d "$extract_dir" ]; then
    log_message ERROR "Directory already exists: $extract_dir"
    log_message ERROR "Skipping to prevent overwriting existing resources"
    add_error "$zip_basename" "Extraction directory already exists" \
      "Directory: $extract_dir\nTo process this ZIP, either:\n1. Remove/rename the existing directory\n2. Move/rename the ZIP file\n3. Process it manually"
    return 1
  fi
  
  mkdir -p "$extract_dir"
  
  # Initialize log file
  {
    echo "========================================="
    echo "OJS XML GENERATION LOG"
    echo "========================================="
    echo "ZIP File: $zip_file"
    echo "Extract Dir: $extract_dir"
    echo "Started: $(date)"
    echo "========================================="
    echo ""
  } > "$log_file"
  
  # Extract ZIP file
  log_message INFO "Extracting ZIP file..."
  echo "=== EXTRACTION ===" >> "$log_file"
  
  if ! unzip -q "$zip_file" -d "$extract_dir" 2>&1 | tee -a "$log_file"; then
    log_message ERROR "Failed to extract ZIP file"
    add_error "$zip_basename" "Failed to extract ZIP file" "$(tail -20 "$log_file")"
    return 1
  fi
  
  log_message SUCCESS "Extraction completed"
  echo "✓ Extraction successful" >> "$log_file"
  echo "" >> "$log_file"
  
  # List extracted contents
  echo "=== EXTRACTED CONTENTS ===" >> "$log_file"
  ls -lah "$extract_dir" >> "$log_file"
  echo "" >> "$log_file"
  
  # Compress large PDFs before processing
  compress_large_pdfs "$extract_dir" "$log_file"
  
  # Find CSV file in extracted contents
  csv_file=$(find "$extract_dir" -maxdepth 2 -name "*.csv" -type f | head -n 1)
  
  if [ -z "$csv_file" ]; then
    log_message ERROR "No CSV file found in extracted contents"
    add_error "$zip_basename" "No CSV file found in extracted directory" "$(ls -R "$extract_dir")"
    return 1
  fi
  
  log_message INFO "Found CSV file: $(basename "$csv_file")"
  echo "CSV file: $csv_file" >> "$log_file"
  echo "" >> "$log_file"
  
  # Find cover image (if exists)
  cover_image=$(find "$extract_dir" -maxdepth 2 \( -name "*cover*" -o -name "*Cover*" \) \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -type f | head -n 1)
  
  if [ -n "$cover_image" ]; then
    log_message INFO "Found cover image: $(basename "$cover_image")"
    echo "Cover image: $cover_image" >> "$log_file"
  else
    log_message WARNING "No cover image found"
    echo "No cover image found" >> "$log_file"
  fi
  echo "" >> "$log_file"
  
  # Check if output directory is writable
  log_message INFO "Checking output directory writability..."
  if [ ! -w "$extract_dir" ]; then
    log_message ERROR "Output directory is not writable: $extract_dir"
    add_error "$zip_basename" "Output directory not writable" "Directory: $extract_dir\nPermissions: $(ls -ld \"$extract_dir\")"
    return 1
  fi
  
  # Test write capability by creating a temporary file
  test_file="$extract_dir/.write_test_$$"
  if ! touch "$test_file" 2>/dev/null; then
    log_message ERROR "Cannot write to output directory: $extract_dir"
    add_error "$zip_basename" "Cannot create files in output directory" "Directory: $extract_dir"
    return 1
  fi
  rm -f "$test_file"
  log_message INFO "Output directory is writable"
  echo "✓ Output directory is writable" >> "$log_file"
  echo "" >> "$log_file"
  
  # Prepare to run process-issue.sh
  # The script expects to be run from the project root and needs interactive input
  # We'll use expect or simulate the inputs
  
  log_message INFO "Running XML generation process..."
  echo "=== XML GENERATION ===" >> "$log_file"
  echo "Started: $(date)" >> "$log_file"
  echo "" >> "$log_file"
  
  # Change to project root
  cd "$PROJECT_ROOT"
  
  # Use process_issue.php if available (better than shell script for automation)
  if [ -f "$PROJECT_ROOT/app/process_issue.php" ]; then
    log_message INFO "Using process_issue.php for processing..."
    
    # Determine the data directory (might be nested one level)
    data_dir="$extract_dir"
    
    # Check if there's a subdirectory with the actual data
    subdirs=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d)
    subdir_count=$(echo "$subdirs" | grep -c "^" || echo 0)
    
    if [ $subdir_count -eq 1 ] && [ -z "$(find "$extract_dir" -maxdepth 1 -name "*.pdf" -type f)" ]; then
      # If there's only one subdirectory and no PDFs in root, use that subdirectory
      data_dir="$subdirs"
      log_message INFO "Using subdirectory: $data_dir"
    fi
    
    # Build command - XML will be written to the extraction directory
    php_cmd="php \"$PROJECT_ROOT/app/process_issue.php\" \"$data_dir\""
    
    if [ -n "$cover_image" ]; then
      php_cmd="$php_cmd \"$(basename "$cover_image")\""
    else
      php_cmd="$php_cmd \"\""
    fi
    
    # Add base_path and username (use BASE_PATH not PROJECT_ROOT)
    php_cmd="$php_cmd \"$BASE_PATH\" master"
    
    # Specify output directory as the extraction folder
    php_cmd="$php_cmd --output=\"$extract_dir\""
    php_cmd="$php_cmd --log-file=\"$log_file\""
    
    if [ "$SKIP_VALIDATION" = false ]; then
      php_cmd="$php_cmd --schema=\"$SCHEMA_FILE\""
    else
      php_cmd="$php_cmd --no-validate"
    fi
    
    log_message INFO "Command: $php_cmd"
    echo "Command: $php_cmd" >> "$log_file"
    echo "" >> "$log_file"
    
    # Execute command
    if eval $php_cmd >> "$log_file" 2>&1; then
      log_message SUCCESS "XML generation completed"
      echo "" >> "$log_file"
      echo "✓ XML generation successful" >> "$log_file"
      
      # Verify XML file was actually created
      xml_created=$(find "$extract_dir" -maxdepth 1 -name "*.xml" -type f -mmin -5 | head -n 1)
      if [ -z "$xml_created" ]; then
        log_message ERROR "XML file was not created in output directory"
        echo "✗ XML file not found after generation" >> "$log_file"
        add_error "$zip_basename" "XML file not created" "Process completed but no XML file found in $extract_dir"
        processing_success=false
      else
        log_message SUCCESS "XML file created: $(basename "$xml_created")"
        echo "✓ XML file: $(basename \"$xml_created\")" >> "$log_file"
        processing_success=true
      fi
    else
      log_message ERROR "XML generation process failed"
      
      # Still check if XML was created (process might have failed during validation)
      xml_created=$(find "$extract_dir" -maxdepth 1 -name "*.xml" -type f -mmin -5 | head -n 1)
      if [ -n "$xml_created" ]; then
        log_message WARNING "XML file was created but process reported failure (likely validation issue)"
        echo "⚠ XML file created: $(basename \"$xml_created\") but validation may have failed" >> "$log_file"
        processing_success=true
      else
        echo "" >> "$log_file"
        echo "✗ XML generation FAILED" >> "$log_file"
        add_error "$zip_basename" "XML generation process failed" "$(tail -50 \"$log_file\")"
        processing_success=false
      fi
    fi
  else
    log_message WARNING "process_issue.php not found, manual processing required"
    echo "⚠ process_issue.php not found" >> "$log_file"
    add_error "$zip_basename" "process_issue.php not found" "Cannot automatically process this issue"
    processing_success=false
  fi
  
  echo "" >> "$log_file"
  
  # Validate generated XML if requested
  if [ "$SKIP_VALIDATION" = false ] && [ "$processing_success" = true ]; then
    # Find generated XML file in the extraction directory
    xml_file=$(find "$extract_dir" -maxdepth 1 -name "*.xml" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$xml_file" ]; then
      log_message INFO "Found generated XML: $(basename "$xml_file")"
      echo "Generated XML: $xml_file" >> "$log_file"
      
      if ! validate_xml "$xml_file" "$log_file"; then
        add_error "$zip_basename" "XML validation failed" "See log file: $log_file"
        processing_success=false
      fi
    else
      log_message WARNING "Could not find generated XML file in extraction directory"
      echo "⚠ Generated XML file not found in $extract_dir" >> "$log_file"
    fi
  fi
  
  # Finalize log
  echo "" >> "$log_file"
  echo "=========================================" >> "$log_file"
  echo "Completed: $(date)" >> "$log_file"
  echo "Status: $([ "$processing_success" = true ] && echo "SUCCESS" || echo "FAILED")" >> "$log_file"
  echo "=========================================" >> "$log_file"
  
  # Clean up if requested and successful
  if [ "$CLEAN_AFTER" = true ] && [ "$processing_success" = true ]; then
    log_message INFO "Cleaning up extraction directory..."
    rm -rf "$extract_dir"
    log_message INFO "Cleanup completed"
  fi
  
  log_message INFO ""
  
  return 0
}

# Function to process an existing folder (without ZIP extraction)
process_existing_folder() {
  local folder_path=$1
  local folder_basename=$(basename "$folder_path")
  local log_file="$folder_path/${folder_basename}_processing.log"
  
  log_message INFO "========================================="
  log_message INFO "Processing existing folder: $folder_basename"
  log_message INFO "========================================="
  
  if [ "$DRY_RUN" = true ]; then
    log_message INFO "[DRY RUN] Would process folder: $folder_path"
    return 0
  fi
  
  # Check if folder has required files (CSV)
  csv_file=$(find "$folder_path" -maxdepth 2 -name "*.csv" -type f | head -n 1)
  
  if [ -z "$csv_file" ]; then
    log_message ERROR "No CSV file found in folder: $folder_path"
    add_error "$folder_basename" "No CSV file found in folder" "$(ls -R "$folder_path")"
    return 1
  fi
  
  # Initialize or append to log file
  {
    echo "========================================="
    echo "OJS XML GENERATION LOG (Existing Folder)"
    echo "========================================="
    echo "Folder: $folder_path"
    echo "Started: $(date)"
    echo "========================================="
    echo ""
  } >> "$log_file"
  
  log_message INFO "Found CSV file: $(basename "$csv_file")"
  echo "CSV file: $csv_file" >> "$log_file"
  echo "" >> "$log_file"
  
  # Compress large PDFs before processing
  compress_large_pdfs "$folder_path" "$log_file"
  
  # Find cover image (if exists)
  cover_image=$(find "$folder_path" -maxdepth 2 \( -name "*cover*" -o -name "*Cover*" \) \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -type f | head -n 1)
  
  if [ -n "$cover_image" ]; then
    log_message INFO "Found cover image: $(basename "$cover_image")"
    echo "Cover image: $cover_image" >> "$log_file"
  else
    log_message WARNING "No cover image found"
    echo "No cover image found" >> "$log_file"
  fi
  echo "" >> "$log_file"
  
  # Check if output directory is writable
  log_message INFO "Checking output directory writability..."
  if [ ! -w "$folder_path" ]; then
    log_message ERROR "Output directory is not writable: $folder_path"
    add_error "$folder_basename" "Output directory not writable" "Directory: $folder_path\\nPermissions: $(ls -ld \"$folder_path\")"
    return 1
  fi
  
  # Test write capability
  test_file="$folder_path/.write_test_$$"
  if ! touch "$test_file" 2>/dev/null; then
    log_message ERROR "Cannot write to output directory: $folder_path"
    add_error "$folder_basename" "Cannot create files in output directory" "Directory: $folder_path"
    return 1
  fi
  rm -f "$test_file"
  log_message INFO "Output directory is writable"
  echo "✓ Output directory is writable" >> "$log_file"
  echo "" >> "$log_file"
  
  # Prepare to run process-issue.sh
  log_message INFO "Running XML generation process..."
  echo "=== XML GENERATION ===" >> "$log_file"
  echo "Started: $(date)" >> "$log_file"
  echo "" >> "$log_file"
  
  # Change to project root
  cd "$PROJECT_ROOT"
  
  # Use process_issue.php if available
  if [ -f "$PROJECT_ROOT/app/process_issue.php" ]; then
    log_message INFO "Using process_issue.php for processing..."
    
    # Determine the data directory (might be nested one level)
    data_dir="$folder_path"
    
    # Check if there's a subdirectory with the actual data
    subdirs=$(find "$folder_path" -mindepth 1 -maxdepth 1 -type d)
    subdir_count=$(echo "$subdirs" | grep -c "^" || echo 0)
    
    if [ $subdir_count -eq 1 ] && [ -z "$(find "$folder_path" -maxdepth 1 -name "*.pdf" -type f)" ]; then
      # If there's only one subdirectory and no PDFs in root, use that subdirectory
      data_dir="$subdirs"
      log_message INFO "Using subdirectory: $data_dir"
    fi
    
    # Build command - XML will be written to the folder directory
    php_cmd="php \"$PROJECT_ROOT/app/process_issue.php\" \"$data_dir\""
    
    if [ -n "$cover_image" ]; then
      php_cmd="$php_cmd \"$(basename "$cover_image")\""
    else
      php_cmd="$php_cmd \"\""
    fi
    
    # Add base_path and username (use BASE_PATH not PROJECT_ROOT)
    php_cmd="$php_cmd \"$BASE_PATH\" master"
    
    # Specify output directory as the folder
    php_cmd="$php_cmd --output=\"$folder_path\""
    php_cmd="$php_cmd --log-file=\"$log_file\""
    
    if [ "$SKIP_VALIDATION" = false ]; then
      php_cmd="$php_cmd --schema=\"$SCHEMA_FILE\""
    else
      php_cmd="$php_cmd --no-validate"
    fi
    
    log_message INFO "Command: $php_cmd"
    echo "Command: $php_cmd" >> "$log_file"
    echo "" >> "$log_file"
    
    # Execute command
    if eval $php_cmd >> "$log_file" 2>&1; then
      log_message SUCCESS "XML generation completed"
      echo "" >> "$log_file"
      echo "✓ XML generation successful" >> "$log_file"
      
      # Verify XML file was actually created
      xml_created=$(find "$folder_path" -maxdepth 1 -name "*.xml" -type f -mmin -5 | head -n 1)
      if [ -z "$xml_created" ]; then
        log_message ERROR "XML file was not created in output directory"
        echo "✗ XML file not found after generation" >> "$log_file"
        add_error "$folder_basename" "XML file not created" "Process completed but no XML file found in $folder_path"
        processing_success=false
      else
        log_message SUCCESS "XML file created: $(basename "$xml_created")"
        echo "✓ XML file: $(basename \"$xml_created\")" >> "$log_file"
        processing_success=true
      fi
    else
      log_message ERROR "XML generation process failed"
      
      # Still check if XML was created (process might have failed during validation)
      xml_created=$(find "$folder_path" -maxdepth 1 -name "*.xml" -type f -mmin -5 | head -n 1)
      if [ -n "$xml_created" ]; then
        log_message WARNING "XML file was created but process reported failure (likely validation issue)"
        echo "⚠ XML file created: $(basename \"$xml_created\") but validation may have failed" >> "$log_file"
        processing_success=true
      else
        echo "" >> "$log_file"
        echo "✗ XML generation FAILED" >> "$log_file"
        add_error "$folder_basename" "XML generation process failed" "$(tail -50 \"$log_file\")"
        processing_success=false
      fi
    fi
  else
    log_message WARNING "process_issue.php not found, manual processing required"
    echo "⚠ process_issue.php not found" >> "$log_file"
    add_error "$folder_basename" "process_issue.php not found" "Cannot automatically process this issue"
    processing_success=false
  fi
  
  echo "" >> "$log_file"
  
  # Validate generated XML if requested
  if [ "$SKIP_VALIDATION" = false ] && [ "$processing_success" = true ]; then
    # Find generated XML file in the folder
    xml_file=$(find "$folder_path" -maxdepth 1 -name "*.xml" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$xml_file" ]; then
      log_message INFO "Found generated XML: $(basename "$xml_file")"
      echo "Generated XML: $xml_file" >> "$log_file"
      
      if ! validate_xml "$xml_file" "$log_file"; then
        add_error "$folder_basename" "XML validation failed" "See log file: $log_file"
        processing_success=false
      fi
    else
      log_message WARNING "Could not find generated XML file in folder"
      echo "⚠ Generated XML file not found in $folder_path" >> "$log_file"
    fi
  fi
  
  # Finalize log
  echo "" >> "$log_file"
  echo "=========================================" >> "$log_file"
  echo "Completed: $(date)" >> "$log_file"
  echo "Status: $([ "$processing_success" = true ] && echo "SUCCESS" || echo "FAILED")" >> "$log_file"
  echo "=========================================" >> "$log_file"
  
  # Clean up if requested and successful
  if [ "$CLEAN_AFTER" = true ] && [ "$processing_success" = true ]; then
    log_message INFO "Cleaning up folder..."
    rm -rf "$folder_path"
    log_message INFO "Cleanup completed"
  fi
  
  log_message INFO ""
  
  return 0
}

# Main execution
main() {
  log_message INFO "========================================="
  log_message INFO "Batch Processing Started"
  log_message INFO "========================================="
  log_message INFO "Project Root: $PROJECT_ROOT"
  log_message INFO "TMP Directory: $TMP_DIR"
  log_message INFO "Output Directory: $OUTPUT_DIR"
  log_message INFO "Batch Log: $BATCH_LOG"
  log_message INFO "Errors File: $ERRORS_FILE"
  log_message INFO ""
  
  # Check if tmp directory exists
  if [ ! -d "$TMP_DIR" ]; then
    log_message ERROR "TMP directory not found: $TMP_DIR"
    exit 1
  fi
  
  # Determine processing mode
  if [ "$PROCESS_FOLDERS" = true ]; then
    # Process existing folders mode
    log_message INFO "Mode: Processing existing folders"
    log_message INFO ""
    
    # Find all directories in tmp (excluding hidden directories)
    folders=()
    while IFS= read -r -d '' folder; do
      folders+=("$folder")
    done < <(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -not -name "upload_*" -print0 | sort -z)
    
    # Check if any folders exist
    if [ ${#folders[@]} -eq 0 ]; then
      log_message WARNING "No folders found in $TMP_DIR"
      exit 0
    fi
    
    folder_count=${#folders[@]}
    log_message INFO "Found $folder_count folder(s) to process"
    log_message INFO ""
    
    # Process each folder
    processed=0
    failed=0
    
    for folder in "${folders[@]}"; do
      if [ -d "$folder" ]; then
        process_existing_folder "$folder"
        result=$?
        
        if [ $result -eq 0 ]; then
          ((processed++))
        else
          ((failed++))
        fi
      fi
    done
    
    log_message INFO ""
    log_message INFO "========================================="
    log_message INFO "Batch Processing Completed"
    log_message INFO "========================================="
    log_message INFO "Total folders: $folder_count"
    log_message INFO "Processed: $processed"
    log_message INFO "Failed: $failed"
    log_message INFO ""
  else
    # Process ZIP files mode (default)
    log_message INFO "Mode: Processing ZIP files"
    log_message INFO ""
    
    # Find all ZIP files in tmp directory
    zip_files=("$TMP_DIR"/*.zip)
    
    # Check if any ZIP files exist
    if [ ! -e "${zip_files[0]}" ]; then
      log_message WARNING "No ZIP files found in $TMP_DIR"
      exit 0
    fi
    
    zip_count=${#zip_files[@]}
    log_message INFO "Found $zip_count ZIP file(s) to process"
    log_message INFO ""
    
    # Process each ZIP file
    processed=0
    failed=0
    
    for zip_file in "${zip_files[@]}"; do
      if [ -f "$zip_file" ]; then
        process_zip "$zip_file"
        result=$?
        
        if [ $result -eq 0 ]; then
          ((processed++))
        else
          ((failed++))
        fi
      fi
    done
    
    log_message INFO ""
    log_message INFO "========================================="
    log_message INFO "Batch Processing Completed"
    log_message INFO "========================================="
    log_message INFO "Total ZIP files: $zip_count"
    log_message INFO "Processed: $processed"
    log_message INFO "Failed: $failed"
    log_message INFO ""
  fi
  
  if [ $failed -gt 0 ]; then
    log_message WARNING "Some files failed processing. Check $ERRORS_FILE for details."
  else
    log_message SUCCESS "All files processed successfully!"
  fi
  
  log_message INFO "Batch log saved to: $BATCH_LOG"
  
  # Show errors file if it has content beyond the header
  if [ "$DRY_RUN" = false ]; then
    error_lines=$(wc -l < "$ERRORS_FILE")
    if [ $error_lines -gt 5 ]; then
      log_message INFO "Errors logged to: $ERRORS_FILE"
    fi
  fi
}

# Run main function
main

exit 0
