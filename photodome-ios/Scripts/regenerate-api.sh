#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOSITORY_ROOT="$(cd "$IOS_ROOT/.." && pwd)"
API_ROOT="$REPOSITORY_ROOT/photodome-api"
SPEC_PATH="$IOS_ROOT/openapi.json"
OUTPUT_DIR="$IOS_ROOT/PhotoDome/Generated"
GENERATOR_TAG="${PHOTODOME_GENERATOR_TAG:-1.10.4}"
GENERATOR_DIR="${PHOTODOME_GENERATOR_DIR:-/tmp/swift-openapi-generator}"

echo "==> Exporting OpenAPI from the NestJS application"
(
  cd "$API_ROOT"
  npm run openapi:export
)

if [ ! -x "$GENERATOR_DIR/.build/release/swift-openapi-generator" ]; then
  echo "==> Building swift-openapi-generator $GENERATOR_TAG"
  if [ ! -d "$GENERATOR_DIR" ]; then
    git clone --depth 1 --branch "$GENERATOR_TAG" \
      https://github.com/apple/swift-openapi-generator.git "$GENERATOR_DIR"
  fi
  (
    cd "$GENERATOR_DIR"
    swift build -c release --product swift-openapi-generator
  )
fi

echo "==> Generating Swift client"
mkdir -p "$OUTPUT_DIR"
"$GENERATOR_DIR/.build/release/swift-openapi-generator" generate \
  --mode types --mode client \
  --naming-strategy idiomatic \
  --access-modifier internal \
  --output-directory "$OUTPUT_DIR" \
  "$SPEC_PATH"

echo "==> Generated client in $OUTPUT_DIR"
"$SCRIPT_DIR/generate-project.sh"
