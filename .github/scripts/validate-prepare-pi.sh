#!/usr/bin/env bash
#
# validate-prepare-pi.sh - Validate prepare_pi.sh modifications
#
# Usage: ./validate-prepare-pi.sh <os-version>
#   os-version: 12 or 13 (determines if Pi 5 checks apply)

set -euo pipefail

OS_VERSION="${1:-12}"

echo "Validating configuration changes..."

# Check cmdline.txt was modified
if grep -q 'console=serial0,115200' /boot/firmware/cmdline.txt; then
  echo "ERROR: console parameter not removed from cmdline.txt"
  exit 1
fi
echo "✓ cmdline.txt correctly modified"

# Check config.txt for disable-bt
if ! grep -q 'dtoverlay=disable-bt' /boot/firmware/config.txt; then
  echo "ERROR: disable-bt not added to config.txt"
  exit 1
fi
echo "✓ disable-bt added to config.txt"

# For OS 13 (Pi 5), check UART settings
if [ "$OS_VERSION" == "13" ]; then
  if ! grep -q 'enable_uart=1' /boot/firmware/config.txt; then
    echo "ERROR: enable_uart not added for Pi 5"
    exit 1
  fi
  
  if ! grep -q 'dtoverlay=uart0,ctsrts' /boot/firmware/config.txt; then
    echo "ERROR: uart0 overlay not added for Pi 5"
    exit 1
  fi
  
  echo "✓ UART configuration added for Pi 5"
fi

echo "All validations passed!"
