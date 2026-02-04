#!/bin/bash

# Script to copy XML files from tmp/ to resources/XML-uri/
# Usage: ./copy-xml-files.sh

# Get the script's directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Define source and destination directories
TMP_DIR="$PROJECT_ROOT/tmp"
RESOURCES_DIR="$PROJECT_ROOT/resources/XML-uri"

# Check if tmp directory exists
if [ ! -d "$TMP_DIR" ]; then
    echo "Error: tmp directory not found at $TMP_DIR"
    exit 1
fi

# Check if resources directory exists, create if not
if [ ! -d "$RESOURCES_DIR" ]; then
    echo "Creating resources directory at $RESOURCES_DIR"
    mkdir -p "$RESOURCES_DIR"
fi

# Count XML files
XML_COUNT=$(find "$TMP_DIR" -type f -name "*.xml" | wc -l)

if [ "$XML_COUNT" -eq 0 ]; then
    echo "No XML files found in $TMP_DIR"
    exit 0
fi

echo "Found $XML_COUNT XML file(s) in tmp directory"
echo "Copying to $RESOURCES_DIR..."

# Find and copy all XML files from tmp to resources
COPIED=0
while IFS= read -r -d '' xml_file; do
    filename=$(basename "$xml_file")
    cp "$xml_file" "$RESOURCES_DIR/$filename"
    echo "Copied: $filename"
    ((COPIED++))
done < <(find "$TMP_DIR" -type f -name "*.xml" -print0)

echo "Done! Copied $COPIED XML file(s) to resources/XML-uri/"
