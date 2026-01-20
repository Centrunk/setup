#!/usr/bin/env bash
#
# setup-pi-mock.sh - Create mock Raspberry Pi environment for testing
#
# Usage: ./setup-pi-mock.sh <pi-version> <os-version>
#   pi-version: 4 or 5
#   os-version: 12 or 13

set -euo pipefail

PI_VERSION="${1:-4}"
OS_VERSION="${2:-12}"

echo "Creating mock Raspberry Pi $PI_VERSION environment (OS $OS_VERSION)..."

# Set environment variables for test mode instead of trying to mock /proc
export TEST_PI_MODEL="Raspberry Pi $PI_VERSION Model B Rev 1.0"
export TEST_OS_VERSION="$OS_VERSION"

# Export to a file that can be sourced
cat > /etc/profile.d/pi-test-env.sh << EOF
export TEST_PI_MODEL="$TEST_PI_MODEL"
export TEST_OS_VERSION="$TEST_OS_VERSION"
EOF

# Create mock os-release
cat > /etc/os-release << EOF
PRETTY_NAME="Raspbian GNU/Linux $OS_VERSION (bookworm)"
NAME="Raspbian GNU/Linux"
VERSION_ID="$OS_VERSION"
VERSION="$OS_VERSION (bookworm)"
ID=raspbian
ID_LIKE=debian
EOF

echo "✓ Mock environment created"
