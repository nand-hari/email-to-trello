#!/bin/bash
set -e

MIGRATION_DIR="src/main/resources/database/migration_flyway/**"
REVERT_DIR="src/main/resources/database/revert_flyway/**"

echo "🔍 Comparing origin/main...HEAD"
git fetch origin main

# Find changed SQL migration files under both dirs
CHANGED_FILES=$(git diff --name-only origin/main...HEAD -- "${MIGRATION_DIR}" "${REVERT_DIR}" \
               | grep -E 'V[0-9]+\.[0-9]+_migration_[0-9]+\.sql$' || true)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "✅ No relevant SQL migration files changed."
  exit 0
fi

echo "📝 Changed files:"
echo "$CHANGED_FILES"

for filepath in $CHANGED_FILES; do
  filename=$(basename "$filepath")
  version=$(echo "$filename" | grep -oE '^V[0-9]+\.[0-9]+')
  suffix=$(echo "$filename" | sed -E "s/^${version}_//")  # e.g. migration_7.sql

  # Check if version already exists on main branch
  existing=$(git ls-tree -r origin/main --name-only | grep -E ".*/${version}_${suffix}$" || true)

  if [[ -n "$existing" ]]; then
    echo "⚠️ Conflict: version $version already exists for $suffix"
    major=$(echo "$version" | cut -c2- | cut -d. -f1)
    minor=$(echo "$version" | cut -c2- | cut -d. -f2)
    new_version="V${major}.$((minor + 1))"
    echo "🔄 Will rename version for $filename → ${new_version}_$suffix"

    for dir in "$MIGRATION_DIR" "$REVERT_DIR"; do
      orig="$dir/${version}_$suffix"
      if [[ -f "$orig" ]]; then
        dst="$dir/${new_version}_$suffix"
        echo "📁 git mv $orig $dst"
        git mv "$orig" "$dst"
      fi
    done
  else
    echo "✅ No conflict for $filename → version $version is unique"
  fi
done

# Commit renames if there are any
if [[ -n "$(git status --porcelain)" ]]; then
  echo "✅ Committing file renames"
  git config user.name "github-actions"
  git config user.email "github-actions@github.com"
  git commit -am "chore: auto-renamed conflicting migration file(s)"
else
  echo "✅ No rename needed"
fi
