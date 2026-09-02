#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
xcodegen generate --spec project.yml
open SetCatcher.xcodeproj
