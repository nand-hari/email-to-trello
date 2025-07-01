#!/bin/bash
set -e

MIGRATION_DIR="src/main/resources/database/migration_flyway"
REVERT_DIR="src/main/resources/database/revert_flyway"
TARGET_DIRS=("$MIGRATION_DIR" "$REVERT_DIR")

git fetch origin main

echo "🔍 Comparing origin/main...HEAD"
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "${TARGET_DIRS[@]}" | grep -E 'V[0-9]+\.[0-9]+_migration_.*\.sql$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "✅ No SQL migration files changed."
  exit 0
fi

echo "📝 Changed files:"
echo "$CHANGED_FILES"

# Build an associative array by suffix
declare -A SUFFIX_TO_FILES

for file in $CHANGED_FILES; do
  filename=$(basename "$file")
  version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')
  suffix=$(echo "$filename" | sed -E "s/^V[0-9]+\.[0-9]+_//")
  key="$suffix"

  SUFFIX_TO_FILES["$key"]="${SUFFIX_TO_FILES[$key]} $file"
done

# Get the highest version from main for versioning
get_latest_version() {
  find src/main/resources/database/migration_flyway -name 'V*_migration_*.sql' |
    grep -oE 'V[0-9]+\.[0-9]+' |
    sort -V |
    tail -n 1
}

LATEST_VERSION=$(get_latest_version)
MAJOR=$(echo "$LATEST_VERSION" | cut -c2- | cut -d. -f1)
MINOR=$(echo "$LATEST_VERSION" | cut -c2- | cut -d. -f2)
NEXT_MINOR=$((MINOR + 1))

# Rename per suffix (ensuring migration + revert get same version)
for suffix in "${!SUFFIX_TO_FILES[@]}"; do
  NEW_VERSION="V${MAJOR}.${NEXT_MINOR}"
  echo "🔄 Renaming files with suffix $suffix to version $NEW_VERSION"

  for filepath in ${SUFFIX_TO_FILES[$suffix]}; do
    dir=$(dirname "$filepath")
    new_filename="${NEW_VERSION}_${suffix}"
    new_path="$dir/$new_filename"

    echo "📁 git mv $filepath $new_path"
    git mv "$filepath" "$new_path"
  done

  NEXT_MINOR=$((NEXT_MINOR + 1))
done

# Commit if needed
if [[ -n "$(git status --porcelain)" ]]; then
  echo "✅ Committing file renames"
  git config user.name "github-actions"
  git config user.email "github-actions@github.com"
  git commit -am "chore: auto-renamed conflicting migration file(s)"
else
  echo "✅ No rename needed"
fi
