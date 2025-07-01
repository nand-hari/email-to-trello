#!/bin/bash
set -e

TARGET_DIR="src/main/resources/database"

# Get list of newly added or modified SQL files in the PR
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "$TARGET_DIR" | grep -E '^'"$TARGET_DIR"'/V[0-9]+\.[0-9]+_migration.*\.sql$' || true)

for file in $CHANGED_FILES; do
    filename=$(basename "$file")
    dir=$(dirname "$file")

    version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')
    suffix=$(echo "$filename" | cut -d'_' -f2-)

    # Check if any file with same version exists (excluding current file)
    existing_files=$(find "$dir" -type f -name "${version}_migration*.sql" ! -path "$file")

    if [ -n "$existing_files" ]; then
        echo "Conflict found for version $version in file $filename"
        
        # Extract major.minor, increment minor version
        major=$(echo $version | cut -d'.' -f1 | tr -d 'V')
        minor=$(echo $version | cut -d'.' -f2)
        new_minor=$((minor + 1))
        new_version="V${major}.${new_minor}"

        new_filename="${new_version}_${suffix}"
        new_path="${dir}/${new_filename}"

        echo "Renaming $file -> $new_path"
        git mv "$file" "$new_path"
    fi
done
