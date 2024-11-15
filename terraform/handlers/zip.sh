#!/bin/bash

# Loop through all Python files in the current directory
for file in *.py; do
    # Check if files exist to avoid errors
    if [ -f "$file" ]; then
        # Get filename without extension
        filename="${file%.py}"
        # Create a zip file containing just this Python file
        rm "${filename}.zip"
        zip "${filename}.zip" "$file"
        echo -e "\033[0mCreated ${filename}.zip containing $file\033[0m"
    fi
done