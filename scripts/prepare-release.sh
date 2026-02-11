#!/bin/bash
set -euo pipefail

VERSION="$1"

echo "==> Preparing release v${VERSION}"

# Step 1: Update MARKETING_VERSION in project.yml
echo "==> Updating MARKETING_VERSION to ${VERSION} in apps/macos/project.yml"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"${VERSION}\"/" apps/macos/project.yml

# Step 2: Generate Xcode project from project.yml
echo "==> Running xcodegen to generate Shire.xcodeproj"
cd apps/macos
xcodegen generate
cd ../..

# Step 3: Build the macOS app (unsigned, Release configuration)
echo "==> Building Shire.app with xcodebuild"
xcodebuild \
  -project apps/macos/Shire.xcodeproj \
  -scheme Shire \
  -configuration Release \
  -derivedDataPath apps/macos/DerivedData \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  build

# Step 4: Locate and zip the built .app
APP_PATH="apps/macos/DerivedData/Build/Products/Release/Shire.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Shire.app not found at $APP_PATH"
  ls -la apps/macos/DerivedData/Build/Products/Release/ 2>/dev/null || echo "Release directory does not exist"
  exit 1
fi

echo "==> Zipping Shire.app"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" Shire.zip

echo "==> Release preparation complete. Shire.zip created ($(du -h Shire.zip | cut -f1))"
