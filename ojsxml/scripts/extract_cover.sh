#!/bin/bash

# Prompt the user for the directory path
read -p "Enter the directory path: " directory_path

# Check if the directory exists
if [ ! -d "$directory_path" ]; then
    echo "Directory does not exist: $directory_path"
    exit 1
fi

# Extract first page of each PDF file and save as JPEG in the same directory
for filename in "$directory_path"/*.pdf; do #directly filtering for .pdf
    if [ -f "$filename" ]; then #check if it's a file
        # Use convert command to extract first page
        convert -density 300 -quality 100 "$filename[0]" "$directory_path/$(basename "$filename" | sed 's/\.pdf$//').jpg"
    fi
done

echo "Done extracting and saving JPEG files in: $directory_path"
