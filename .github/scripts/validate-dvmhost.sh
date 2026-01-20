#!/usr/bin/env bash
#
# validate-dvmhost.sh - Validate install_dvmhost.sh installation
#
# Usage: ./validate-dvmhost.sh

set -euo pipefail

echo "Validating installation..."

# Check directories were created
for dir in /var/log/centrunk /opt/centrunk /opt/centrunk/configs; do
  if [ ! -d "$dir" ]; then
    echo "ERROR: Directory $dir was not created"
    exit 1
  fi
done
echo "✓ Required directories created"

# Check packages were installed
for pkg in git nano; do
  if ! command -v $pkg &> /dev/null; then
    echo "ERROR: Package $pkg not installed"
    exit 1
  fi
done
echo "✓ Required packages installed"


echo "All validations passed!"
