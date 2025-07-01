#!/bin/bash
set -e
set -x  # <-- DEBUG: print every command

TARGET_DIR="src/main/resources/database/migration_flyway"

# Compare PR head with main
echo "Comparing origin/main...HEAD"
git fetch origin main
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "$TARGET_DIR" \
  | grep -E '^'"${TARGET_DIR}"'/V[0-9]+\.[0-9]+_migration.*\.sql$' || true)

echo "Changed .sql files detected:"
echo "$CHANGED_FILES"

for file in $CHANGED_FILES; do
  echo "- Processing: $file"
  filename=$(basename "$file")
  dir=$(dirname "$file")
  echo "  basename=$filename, dir=$dir"

  version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')
  echo "  version=$version"

  # Find existing files excluding the current one
  existing=$(find "$dir" -maxdepth 1 -type f \
    -name "${version}_migration*.sql" ! -samefile "$file")
  echo "  existing-version files:"
  echo "$existing"

  if [[ -n "$existing" ]]; then
    echo "  ➤ Version conflict detected for $version"
    major=$(echo ${version#V} | cut -d. -f1)
    minor=$(echo ${version#V} | cut -d. -f2)
    new_minor=$((minor+1))
    new_version="V${major}.${new_minor}"
    suffix="${filename#${version}_}"
    new_filename="${new_version}_${suffix}"
    new_path="${dir}/${new_filename}"
    echo "  ➤ Renaming to $new_filename"
    git mv "$file" "$new_path"
  else
    echo "  ✔ No conflict for $version"
  fi
done
