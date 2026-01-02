#!/bin/bash

# Configuration
APP_NAME="Pensive"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

echo "🚀 Building ${APP_NAME} in release mode..."

# 1. Build the executable
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# 2. Ensure bundle structure exists
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. Copy the binary
BINARY_PATH=$(swift build -c release --show-bin-path)/${APP_NAME}
cp "${BINARY_PATH}" "${MACOS_DIR}/"

# 4. Copy Resources
if [ -d "Sources/${APP_NAME}/Resources" ]; then
    echo "📦 Copying resources..."
    cp -R "Sources/${APP_NAME}/Resources/" "${RESOURCES_DIR}/"
fi

# 5. Fix permissions
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "✅ Successfully built ${APP_BUNDLE}"
echo "✨ You can now run the app with: open ${APP_BUNDLE}"
