#!/bin/bash
# Source the .env file (if it exists)
if [ -f .env ]; then
    source .env
fi

# Set the directory containing the PDF files
#pdf_directory="~/Downloads/PLATFORMA.EDITORIALA/DATE/DATA/DATA-PROCESSED/Annals of the University of Bucharest – Geography Series/2022" # Replace with the actual path to your PDF files
# Prompt the user for the PDF directory and issue cover image file
read -p "Enter the path to the PDF directory: " pdf_directory
read -p "Enter the name of the issue cover image file: " issue_cover_image_file

# Check if the directory exists
if [ ! -d "$pdf_directory" ]; then
  echo "Error: Directory '$pdf_directory' not found."
  exit 1
fi

# Set the output directories using the base path (from .env or default)
base_path="${BASE_PATH:-"/home/nicolaie/Documents/PLATFORMA.EDITORIALA/DATE"}" # Use .env value or default

# Set the directory where you want to copy the processed JPG files
#jpg_output_directory="/home/nicolaie/Downloads/PLATFORMA.EDITORIALA/DATE/ojsxml/docroot/csv/abstracts/issue_cover_images" # Replace with the desired output path for JPGs
jpg_output_directory="$base_path/ojsxml/docroot/csv/abstracts/issue_cover_images"
# Set the directory where you want to copy the PDF files
#pdf_output_directory="/home/nicolaie/Downloads/PLATFORMA.EDITORIALA/DATE/ojsxml/docroot/csv/abstracts/article_galleys" # Replace with the desired output path for PDFs
pdf_output_directory="$base_path/ojsxml/docroot/csv/abstracts/article_galleys"
# Set the directory where you want to copy the CSV file
#csv_output_directory="/home/nicolaie/Downloads/PLATFORMA.EDITORIALA/DATE/ojsxml/docroot/csv/abstracts"  # Change if needed
csv_output_directory="$base_path/ojsxml/docroot/csv/abstracts"
# Set rootdirectory and output_directory for php command
rootdirectory="$base_path/ojsxml/docroot/csv/abstracts"
output_directory="$base_path/ojsxml/docroot/output"

# Determine the username
username="${USERNAME:-"master"}" # Use .env value or default "default_user"

# Create the output directories if they don't exist
mkdir -p "$jpg_output_directory"
mkdir -p "$pdf_output_directory"
mkdir -p "$csv_output_directory"
mkdir -p "$output_directory" # Create the output directory for PHP as well

# Clear output directories (except .gitkeep)
find "$jpg_output_directory" -mindepth 1 -not -name ".gitkeep" -delete
find "$pdf_output_directory" -mindepth 1 -not -name ".gitkeep" -delete
find "$csv_output_directory" -mindepth 1 -not -name ".gitkeep" -delete

# Loop through all PDF files in the directory and generate JPEGs of the first page
for pdf_file in "$pdf_directory"/*.pdf; do
  # Extract the filename without the extension
  filename=$(basename "$pdf_file" .pdf)
  # Construct the output JPEG filename in the new directory
  output_jpg="$jpg_output_directory/$filename"
  # Run pdftocairo for each PDF file
  pdftocairo -jpeg -singlefile -f 1 -l 1 -scale-to-x 600 -scale-to-y -1 "$pdf_file" "$output_jpg"
  # Check if the command was successful (optional but recommended)
  if [ $? -eq 0 ]; then 
     echo "Processed: $pdf_file -> $output_jpg"
     # Copy the PDF to the specified output directory
     cp "$pdf_file" "$pdf_output_directory" 
  else 
     echo "Error processing: $pdf_file" 
  fi
done

# Change to the directory where the PHP script is located
cd "$base_path/ojsxml"

# Find and copy the CSV file (if it exists)
csv_file=$(find "$pdf_directory" -maxdepth 1 -name "*.csv" -print -quit) # Find CSV in pdf_directory only

# Check if CSV file was found. If not, exit with an error.
if [[ -z "$csv_file" ]]; then  # -z checks for empty string
  echo "Error: No CSV file found in '$pdf_directory'.  Exiting."
  exit 1  # Exit with a non-zero status to indicate an error
fi

echo "Found CSV file: $csv_file"
cp "$csv_file" "$csv_output_directory"
if [ $? -eq 0 ]; then
    echo "Copied CSV file: $csv_file -> $csv_output_directory"
else
    echo "Error copying CSV file: $csv_file"
    exit 1 #Exit if the copy fails
fi

# Find and copy the cover image file (if it exists)
coverimg_file=""
if [[ -n "$issue_cover_image_file" ]]; then
  coverimg_file=$(find "$pdf_directory/$issue_cover_image_file" -maxdepth 1 -print -quit)
fi
if [[ -z "$coverimg_file" ]]; then  # -z checks for empty string
  echo "No cover image file found in '$pdf_directory'."
else
  echo "Found cover image file: $coverimg_file"
  cp "$coverimg_file" "$csv_output_directory"
  if [ $? -eq 0 ]; then
      echo "Copied cover image file: $coverimg_file -> $csv_output_directory"
  else
      echo "Error copying cover image file: $coverimg_file"
      exit 1 #Exit if the copy fails
  fi
fi
# Go back to the original directory (important!)
cd - > /dev/null  # Or cd $OLDPWD if you saved it earlier

# Launch the PHP command
php "$base_path/ojsxml/csvToXmlConverter.php" issues "$username" "$rootdirectory" "$output_directory"

# Check if the PHP command was successful
if [ $? -eq 0 ]; then
    echo "PHP command executed successfully."
else
    echo "Error executing PHP command."
fi

echo "Finished processing all PDF files."
