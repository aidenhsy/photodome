#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
xcrun swift-format format --in-place --recursive \
  --configuration .swift-format \
  PhotoDome/Design \
  PhotoDome/Domain \
  PhotoDome/Features \
  PhotoDome/Services \
  PhotoDome/AppDelegate.swift \
  PhotoDome/PhotoDomeApp.swift \
  PhotoDomeLiveActivity \
  Shared \
  PhotoDomeTests
