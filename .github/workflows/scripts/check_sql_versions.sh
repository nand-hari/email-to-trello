#!/bin/bash

set -e

MIGRATION_DIR="src/main/resources/database/migration_flyway"
REVERT_DIR="src/main/resources/database/revert_flyway"

echo "🔍 Comparing origin/main...HEAD"
git fetch origin main

# Detect changed migration and revert SQL files
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "$MIGRATION_DIR" "$REVERT_DIR" | grep -E '^.*V[0-9]+\.[0-9]+_migration.*\.sql$')

if [[ -z "$CHANGED_FILES" ]]; then
    echo "✅ No relevant SQL files changed."
    exit 0
fi

echo "📝 Changed files:"
echo "$CHANGED_FILES"

declare -A VERSION_GROUPS

# Group changed files by version prefix (e.g., V1.2)
for file in $CHANGED_FILES; do
    filename=$(basename "$file")
    version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')
    [[ -n "$version" ]] && VERSION_GROUPS["$version"]+=("$file")
done

# For each version group, check for conflict and rename all related files
for version in "${!VERSION_GROUPS[@]}"; do
    echo "🔍 Checking for conflicts for version: $version"

    existing_files=$(find "$MIGRATION_DIR" "$REVERT_DIR" -type f -name "${version}_migration*.sql" \
        ! -samefile "${VERSION_GROUPS[$version][0]}")

    if [[ -n "$existing_files" ]]; then
        echo "⚠️  Conflict detected for $version"

        # Extract numeric parts to calculate next version
        numeric_version=${version:1}
        major=$(echo "$numeric_version" | cut -d. -f1)
        minor=$(echo "$numeric_version" | cut -d. -f2)

        new_minor=$((minor + 1))
        new_version="V$major.$new_minor"

        echo "➕ Renaming to new version: $new_version"

        for file in "${VERSION_GROUPS[$version][@]}"; do
            dir=$(dirname "$file")
            base=$(basename "$file")
            suffix=${base#*_}  # e.g., migration_2.sql
            new_filename="${new_version}_${suffix}"
            new_path="$dir/$new_filename"

            echo "📦 Renaming $file → $new_path"
            git mv "$file" "$new_path"
        done
    else
        echo "✅ No conflicts found for $version"
    fi
done
