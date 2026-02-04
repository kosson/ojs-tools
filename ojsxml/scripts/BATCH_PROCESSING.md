# Batch Processing Script Documentation

## Overview

The `batch-processing.sh` script automates the processing of multiple OJS XML generation tasks. It supports two modes:

1. **ZIP Mode (default)** - Processes ZIP archives from the `tmp/` directory
2. **Folder Mode** - Processes existing unzipped folders directly

Both modes generate XML files, validate them, and create detailed logs.

## Features

- ✅ **Automatic ZIP extraction** - Unzips each file into its own subfolder
- ✅ **Safety checks** - Skips processing if extraction folder already exists (prevents overwriting)
- ✅ **Automated processing** - Runs XML generation for each issue automatically
- ✅ **PDF compression** - Automatically compresses large PDFs (>500KB) using Ghostscript to reduce XML size
- ✅ **Self-contained output** - XML files are generated in the same folder as the source files
- ✅ **Detailed logging** - Creates individual log files for each processed issue
- ✅ **Error tracking** - Generates a consolidated `errors.md` file for easy inspection
- ✅ **XML validation** - Validates generated XML files against the schema
- ✅ **Batch reporting** - Creates a timestamped batch log with overall summary
- ✅ **Dry run mode** - Preview what will be processed without making changes
- ✅ **Cleanup option** - Optionally remove extracted folders after processing

## Requirements

- Bash shell (Linux/Unix/macOS)
- `unzip` command
- `xmllint` for XML validation (usually part of libxml2)
- `gs` (Ghostscript) for PDF compression
- PHP with required extensions
- Access to the OJS XML project structure

## Usage

### Basic Usage

**Process ZIP files (default):**

```bash
cd /home/nicolaie/Documents/PLATFORMA.EDITORIALA/DATE/ojsxml/scripts
./batch-processing.sh
```

**Process existing folders:**

```bash
./batch-processing.sh --process-folders
```

### Command Line Options

```bash
./batch-processing.sh [options]
```

**Available Options:**

- `--dry-run` - Preview what would be processed without actually doing it
- `--skip-validation` - Skip XML schema validation (faster but not recommended)
- `--clean` - Remove extracted folders after successful processing
- `--process-folders` - Process existing unzipped folders instead of ZIP files
- `--help` or `-h` - Show help message

### Examples

**Dry run to see what would be processed:**

```bash
./batch-processing.sh --dry-run
```

**Process existing folders without validation:**

```bash
./batch-processing.sh --process-folders --skip-validation
```

**Process all ZIPs and clean up after:**

```bash
./batch-processing.sh --clean
```

**Process folders without validation (faster):**

```bash
./batch-processing.sh --process-folders --skip-validation
```

**Combine multiple options:**

```bash
./batch-processing.sh --skip-validation --clean
```

## Input Structure

### ZIP Mode (Default)

The script expects ZIP files to be placed in the `tmp/` directory. Each ZIP should contain:

1. **PDF files** - Article PDFs (required)
2. **CSV file** - Issue metadata (required)
3. **Cover image** (optional) - Should contain "cover" in filename (e.g., `cover.jpg`, `issue_cover.png`)

#### Example ZIP Structure

```
tmp/
├── aub-geography_vol61.zip
│   ├── article1.pdf
│   ├── article2.pdf
│   ├── article3.pdf
│   ├── vol61_metadata.csv
│   └── cover.jpg
├── aub-geography_vol62.zip
└── aub-geography_vol63.zip
```

### Folder Mode (--process-folders)

The script processes existing folders in the `tmp/` directory. Each folder should contain:

1. **PDF files** - Article PDFs (required)
2. **CSV file** - Issue metadata (required)
3. **Cover image** (optional) - Should contain "cover" in filename

#### Example Folder Structure

```
tmp/
├── aub-geography_vol61/
│   ├── article1.pdf
│   ├── article2.pdf
│   ├── vol61_metadata.csv
│   └── cover.jpg
├── aub-geography_vol62/
│   ├── article1.pdf
│   ├── vol62_metadata.csv
│   └── issue_cover.png
└── aub-geography_vol63/
```

**Note:** When using `--process-folders`, the script ignores:

- Hidden directories (starting with `.`)
- Upload temporary directories (starting with `upload_`)
- ZIP files (they are not processed in folder mode)

## Output Structure

After processing, the script generates:

### 1. Extracted Folders (in `tmp/`)

Each ZIP is extracted to a subfolder named after the ZIP file:

```
tmp/
├── aub-geography_vol61/           # Extracted contents
│   ├── article1.pdf
│   ├── article2.pdf
│   ├── vol61_metadata.csv
│   ├── cover.jpg
│   └── aub-geography_vol61_processing.log  # Individual log
├── aub-geography_vol62/
└── batch_processing_20260112_143025.log     # Batch log
```

### 2. Individual Processing Logs

Each processed issue gets its own log file in its extraction folder:

**Format:** `<zip_basename>_processing.log`

**Contains:**

- Extraction details
- File listings
- XML generation output
- Validation results
- Error messages (if any)

### 3. Batch Processing Log

A timestamped log in `tmp/` directory:

**Format:** `batch_processing_YYYYMMDD_HHMMSS.log`

**Contains:**

- Overall batch processing summary
- Status of each ZIP file
- Final statistics

### 4. Errors File

**Location:** `tmp/errors.md`

A markdown file that consolidates all errors encountered during batch processing. Each error entry includes:

- ZIP file name
- Timestamp
- Error message
- Detailed error output

**Example:**

```markdown
# Batch Processing Errors

**Generated:** 2026-01-12 14:30:25

## Error in: aub-geography_vol61

**Time:** 2026-01-12 14:32:10

**Error:** No CSV file found in extracted directory

**Details:**
\```
ls output showing directory contents...
\```

---
```

### 5. Generated XML Files

XML files are created in the **same folder as the extracted ZIP contents**:

**Location:** `tmp/<zip_basename>/<generated_filename>.xml`

**Example:**

```
tmp/
├── aub-geography_vol61/
│   ├── article1.pdf
│   ├── vol61_metadata.csv
│   ├── cover.jpg
│   ├── Annals-Geography-2022-vol61-iss1.xml  ← Generated XML
│   └── aub-geography_vol61_processing.log
```

**Format:** The XML filename is dynamically generated based on CSV metadata (issue title, year, volume, issue number).

## Workflow Details

### For Each ZIP File

1. **Extract**
   - Creates subfolder: `tmp/<zip_basename>/`
   - Extracts all contents
   - Logs extraction results

2. **Validate Contents**
   - Searches for required CSV file
   - Searches for optional cover image
   - Logs findings

3. **Compress PDFs**
   - Automatically compresses PDFs larger than 500KB using Ghostscript
   - Uses `/ebook` quality setting (good balance between quality and size)
   - Typical compression: 50-95% size reduction
   - Skips compression if result would be larger
   - Logs compression results for each file

4. **Process**
   - Calls `app/process_issue.php` with appropriate parameters
   - Passes `--output=<extraction_dir>` to write XML in the same folder
   - Passes log file path for detailed logging
   - Includes schema path for validation

5. **Validate XML**
   - Locates generated XML file
   - Runs `xmllint` validation against schema
   - Logs validation results
   - Records errors if validation fails

6. **Clean Up (Optional)**
   - If `--clean` flag is used and processing succeeded
   - Removes extraction folder
   - Preserves log files and generated XML

## Error Handling

The script handles errors gracefully:

- **Missing CSV**: Logs error and continues to next ZIP
- **Extraction failure**: Records in errors.md, continues processing
- **XML generation failure**: Captures output, adds to errors.md
- **Validation failure**: Records validation errors in log and errors.md
- **Missing dependencies**: Reports and exits appropriately

## Color-Coded Output

The script uses color-coded console output for easy reading:

- 🔴 **Red** - Errors
- 🟢 **Green** - Success messages
- 🟡 **Yellow** - Warnings
- 🔵 **Blue** - Info messages

## Logging Levels

Each log entry includes:

- `[ERROR]` - Critical errors that stopped processing
- `[SUCCESS]` - Successful operations
- `[WARNING]` - Non-critical issues
- `[INFO]` - General information

## Best Practices

### Before Running

1. **Backup important data** - Especially if using `--clean` option
2. **Check ZIP contents** - Ensure each ZIP has required CSV file
3. **Test with dry run** - Use `--dry-run` first
4. **Check disk space** - Ensure adequate space for extraction

### During Processing

1. **Monitor the output** - Watch for any error messages
2. **Don't interrupt** - Let the script complete all files
3. **Check logs** - Review individual logs for issues

### After Processing

1. **Review errors.md** - Check if any issues occurred
2. **Validate XML files** - Open generated XMLs in browser/editor
3. **Clean up** - Remove extraction folders if not needed
4. **Archive logs** - Save batch logs for record keeping

## Troubleshooting

### No ZIP files found

**Problem:** Script reports no ZIP files
**Solution:** Ensure ZIP files are in `tmp/` directory with `.zip` extension

### Extraction fails

**Problem:** ZIP extraction errors
**Solution:**

- Check ZIP file integrity
- Ensure proper permissions on `tmp/` directory
- Verify `unzip` command is available

### Directory already exists error

**Problem:** Script reports "Directory already exists" and skips processing
**Solution:** 

- This is a **safety feature** to prevent overwriting existing work
- Options:
  1. Remove or rename the existing directory: `mv tmp/issue_name tmp/issue_name.backup`
  2. Rename the ZIP file: `mv issue.zip issue_v2.zip`
  3. Process manually with a different output location
- Check if the existing directory contains important work before removing

### XML validation fails

**Problem:** Validation errors in logs
**Solution:**

- Check CSV data format
- Review validation error details in log
- Verify schema file exists: `schema/schema_3_5.xsd`
- Check generated XML against schema requirements

### PHP errors

**Problem:** PHP script execution fails
**Solution:**

- Verify PHP is installed: `php --version`
- Check PHP extensions
- Review individual processing logs

### Permission denied

**Problem:** Cannot create directories/files
**Solution:**

```bash
chmod +x scripts/batch-processing.sh
chmod -R 755 tmp/
```

## Integration with Existing Tools

The batch processing script works alongside:

- `process-issue.sh` - Individual issue processing
- `app/process_issue.php` - Core PHP processing script
- XML validation tools - Schema validation

## Performance Considerations

### Processing Time

Approximate time per issue:

- ZIP extraction: 1-5 seconds
- XML generation: 10-30 seconds
- Validation: 2-5 seconds

**Total:** ~20-40 seconds per issue

For 10 ZIP files: ~5-7 minutes

### Resource Usage

- **Disk space**: Temporary space for extracted files (2-3x ZIP size)
- **Memory**: Minimal (PHP processing requires ~64MB)
- **CPU**: Moderate during PDF processing

## Maintenance

### Regular Tasks

1. **Clean old logs** - Remove outdated batch logs from `tmp/`
2. **Archive processed ZIPs** - Move processed ZIPs to archive folder
3. **Review errors.md** - Check for recurring issues
4. **Update schema** - Keep validation schema up to date

### Monitoring

Check these regularly:

- `tmp/` directory size
- Generated XML quality
- Error patterns in `errors.md`
- Processing time trends

---

**Last Updated:** January 12, 2026
