#!/usr/bin/env bash
#
# mock-netbird.sh - Mock NetBird installer for testing
#
# Usage: ./mock-netbird.sh

set -euo pipefail

echo "Setting up mock NetBird installer..."

# Create mock installer script
mkdir -p /tmp/mock-scripts
cat > /tmp/mock-scripts/netbird-install.sh << 'NETBIRD'
#!/bin/bash
echo "Mock NetBird installation"
mkdir -p /usr/local/bin
cat > /usr/local/bin/netbird << 'NB'
#!/bin/bash
echo "netbird version 0.0.0-mock"
NB
chmod +x /usr/local/bin/netbird
NETBIRD
chmod +x /tmp/mock-scripts/netbird-install.sh

# Create curl wrapper
cat > /usr/local/bin/curl-wrapper << 'CURL'
#!/bin/bash
if [[ "$@" =~ "netbird" ]]; then
  exec /tmp/mock-scripts/netbird-install.sh
else
  exec /usr/bin/curl.real "$@"
fi
CURL
chmod +x /usr/local/bin/curl-wrapper

# Replace curl with wrapper
mv /usr/bin/curl /usr/bin/curl.real
ln -s /usr/local/bin/curl-wrapper /usr/bin/curl

echo "✓ Mock NetBird installer ready"
