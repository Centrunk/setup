#!/usr/bin/env bash
#
# restore-curl.sh - Restore original curl after testing
#
# Usage: ./restore-curl.sh

set -euo pipefail

echo "Restoring original curl..."

if [ -f /usr/bin/curl.real ]; then
  rm -f /usr/bin/curl
  mv /usr/bin/curl.real /usr/bin/curl
  echo "✓ curl restored"
else
  echo "No backup curl found, skipping"
fi
