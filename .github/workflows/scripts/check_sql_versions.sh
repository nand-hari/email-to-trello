#!/bin/bash
set -e

MIGRATION_DIR="src/main/resources/database/migration_flyway"
REVERT_DIR="src/main/resources/database/revert_flyway"
TARGET_DIRS=("$MIGRATION_DIR" "$REVERT_DIR")

echo "🔍 Comparing origin/main...HEAD"
git fetch origin main

# Find changed SQL files
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "${TARGET_DIRS[@]}" | grep -E 'V[0-9]+\.[0-9]+_migration.*\.sql$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "✅ No SQL migration files changed."
  exit 0
fi

echo "📝 Changed files:"
echo "$CHANGED_FILES"

# Track current max version in the repo
ALL_EXISTING=$(find "${TARGET_DIRS[@]}" -type f -name 'V*_migration*.sql' | grep -oE 'V[0-9]+\.[0-9]+' | sort -u)
LAST_VERSION=$(echo "$ALL_EXISTING" | sort -V | tail -n1)
major=$(echo "$LAST_VERSION" | cut -c2- | cut -d. -f1)
minor=$(echo "$LAST_VERSION" | cut -c2- | cut -d. -f2)
next_minor=$((minor + 1))

# Process and rename each unique file pair
declare -A seen_base

for file in $CHANGED_FILES; do
  filename=$(basename "$file")
  dirname=$(dirname "$file")

  base=$(echo "$filename" | sed -E 's/^V[0-9]+\.[0-9]+_//')  # e.g., migration_5.sql

  if [[ -z "${seen_base[$base]}" ]]; then
    new_version="V${major}.${next_minor}"
    next_minor=$((next_minor + 1))

    for dir in "${TARGET_DIRS[@]}"; do
      old_path="$dir/V1.4_$base"
      new_path="$dir/${new_version}_$base"

      if [[ -f "$old_path" ]]; then
        echo "📁 git mv $old_path $new_path"
        git mv "$old_path" "$new_path"
      fi
    done

    seen_base[$base]=$new_version
  fi
done

# Commit the changes
if [[ -n "$(git status --porcelain)" ]]; then
  echo "✅ Committing file renames"
  git config user.name "github-actions"
  git config user.email "github-actions@github.com"
  git commit -am "chore: auto-renamed conflicting migration file(s)"
else
  echo "✅ No rename needed"
fi
