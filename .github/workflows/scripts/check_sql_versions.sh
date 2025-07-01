#!/bin/bash

set -e

TARGET_DIR="src/main/resources/database"

# List newly added SQL files
FILES=$(git diff --name-status origin/main | awk '/^A/ {print $2}' | grep "^$TARGET_DIR/.*\.sql$")

for FILE in $FILES; do
  FILENAME=$(basename "$FILE")
  DIRNAME=$(dirname "$FILE")

  # Extract version (e.g., V1.1) and name (e.g., migration.sql)
  VERSION=$(echo "$FILENAME" | sed -n 's/^\(V[0-9]\+\.[0-9]\+\)_\(.*\)$/\1/p')
  BASE_NAME=$(echo "$FILENAME" | sed -n 's/^V[0-9]\+\.[0-9]\+_\(.*\)$/\1/p')

  # If not matching expected format, skip
  [[ -z "$VERSION" || -z "$BASE_NAME" ]] && continue

  MAJOR=$(echo "$VERSION" | cut -d. -f1 | sed 's/V//')
  MINOR=$(echo "$VERSION" | cut -d. -f2)

  # Find the highest minor version with same major
  MAX_VERSION=$(find "$DIRNAME" -name "V${MAJOR}.*_*.sql" \
    | sed -n "s/^.*\/V${MAJOR}\.\([0-9]\+\)_.*$/\1/p" | sort -n | tail -1)

  [[ -z "$MAX_VERSION" ]] && MAX_VERSION=$MINOR

  if find "$DIRNAME" -name "V${VERSION}_*.sql" | grep -q .; then
    NEW_MINOR=$((MAX_VERSION + 1))
    NEW_VERSION="V${MAJOR}.${NEW_MINOR}"
    NEW_FILENAME="${NEW_VERSION}_${BASE_NAME}"
    NEW_PATH="${DIRNAME}/${NEW_FILENAME}"

    echo "Conflict found for $FILENAME, renaming to $NEW_FILENAME"
    mv "$FILE" "$NEW_PATH"
    git add "$NEW_PATH"
    git rm "$FILE"
  fi
done
