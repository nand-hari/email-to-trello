#!/bin/bash
set -e

MIGRATION_DIR="src/main/resources/database/migration_flyway"
REVERT_DIR="src/main/resources/database/revert_flyway"
TARGET_DIRS=("$MIGRATION_DIR" "$REVERT_DIR")

echo "🔍 Comparing origin/main...HEAD"
git fetch origin main

# Find changed SQL files in both directories
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "${TARGET_DIRS[@]}" | grep -E 'V[0-9]+\.[0-9]+_migration.*\.sql$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "✅ No SQL migration files changed."
  exit 0
fi

echo "📝 Changed files:"
echo "$CHANGED_FILES"

# Group by version
declare -A VERSION_GROUPS

for file in $CHANGED_FILES; do
  filename=$(basename "$file")
  version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')

  echo "➡️  Processing file: $filename (version: $version)"
  VERSION_GROUPS["$version"]="${VERSION_GROUPS["$version"]} $file"
done

# Process each version group
for version in "${!VERSION_GROUPS[@]}"; do
  echo "🔧 Checking for conflicts with version $version"

  for dir in "${TARGET_DIRS[@]}"; do
    existing=$(find "$dir" -maxdepth 1 -type f -name "${version}_migration*.sql" || true)

    # Skip if no existing conflicts
    if [[ -z "$existing" ]]; then
      continue
    fi

    echo "⚠️  Conflict detected for $version in $dir"
    
    # Increment minor version
    major=$(echo "$version" | cut -c2- | cut -d. -f1)
    minor=$(echo "$version" | cut -c2- | cut -d. -f2)
    new_minor=$((minor + 1))
    new_version="V${major}.${new_minor}"

    echo "🔄 Renaming to version $new_version"

    # Rename all files in this version group
    for filepath in ${VERSION_GROUPS[$version]}; do
      filename=$(basename "$filepath")
      suffix=$(echo "$filename" | sed -E "s/^${version}_//")
      new_filename="${new_version}_${suffix}"
      new_path="$(dirname "$filepath")/$new_filename"

      echo "📁 git mv $filepath $new_path"
      git mv "$filepath" "$new_path"
    done
  done
done

# Commit the renames if there are changes
if [[ -n "$(git status --porcelain)" ]]; then
  echo "✅ Committing file renames"
  git config user.name "github-actions"
  git config user.email "github-actions@github.com"
  git commit -am "chore: auto-renamed conflicting migration file(s)"
else
  echo "✅ No rename needed"
fi
