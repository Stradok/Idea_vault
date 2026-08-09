#!/usr/bin/env bash
# Vercel has no native Flutter support, so this script installs the Flutter
# SDK itself as part of the build, then builds the web target.
set -euo pipefail

# .env is gitignored (never committed) — write it here from Vercel's own
# Environment Variables (Project Settings -> Environment Variables), so the
# web build bundles the real config instead of an empty one.
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}
EOF

if [ ! -d "_flutter_sdk" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter_sdk
fi
export PATH="$PWD/_flutter_sdk/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release
