#!/usr/bin/env bash
# One-shot setup for the iOS app. Run after cloning, after installing Xcode,
# and any time you add or rename a source file.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

PLIST="ClaudePlanner/GoogleService-Info.plist"
if [[ ! -f "$PLIST" ]]; then
  cat <<EOF

WARNING: $PLIST is missing.
  1. Firebase Console -> your project -> Project Settings (see personal.md)
  2. Add iOS app with the bundle id configured in project.yml
  3. Download GoogleService-Info.plist and save it to:
     $(pwd)/$PLIST
  4. Re-run this script.

Also make sure ios-app/Config.local.xcconfig exists (copy from .example
and set RELAY_BASE_URL to your relay HTTPS endpoint).
EOF
fi

echo "Done. Open ClaudePlanner.xcodeproj in Xcode."
