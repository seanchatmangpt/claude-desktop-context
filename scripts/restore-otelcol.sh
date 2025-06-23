#!/bin/bash
# Restore OpenTelemetry Collector binaries

set -e

echo "=== Restoring OpenTelemetry Collector Binaries ==="

# Version used in CDCS
OTEL_VERSION="0.91.0"
PLATFORM="darwin_amd64"
DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_${PLATFORM}.tar.gz"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloading OpenTelemetry Collector v${OTEL_VERSION}..."
if command -v curl &> /dev/null; then
    curl -L -o otelcol.tar.gz "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O otelcol.tar.gz "$DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

echo "Extracting..."
tar -xzf otelcol.tar.gz

echo "Restoring binaries..."
cp otelcol /Users/sac/claude-desktop-context/automation/telemetry/
cp otelcol /Users/sac/claude-desktop-context/telemetry/

echo "Setting permissions..."
chmod +x /Users/sac/claude-desktop-context/automation/telemetry/otelcol
chmod +x /Users/sac/claude-desktop-context/telemetry/otelcol

echo "Cleaning up..."
cd -
rm -rf "$TEMP_DIR"

echo "✅ OpenTelemetry Collector binaries restored successfully!"
echo "   - automation/telemetry/otelcol"
echo "   - telemetry/otelcol"
