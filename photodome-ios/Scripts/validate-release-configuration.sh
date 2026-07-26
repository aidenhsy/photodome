#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

case "${PHOTODOME_API_BASE_URL:-}" in
  https://*)
    ;;
  *)
    echo "error: Release builds require PHOTODOME_RELEASE_API_BASE_URL with an https:// URL." >&2
    exit 1
    ;;
esac

case "${PHOTODOME_API_BASE_URL}" in
  *localhost*|*127.0.0.1*|*.invalid*)
    echo "error: Release API URL must not target localhost or a reserved invalid domain." >&2
    exit 1
    ;;
esac
