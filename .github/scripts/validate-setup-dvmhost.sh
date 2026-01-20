#!/usr/bin/env bash
#
# validate-setup-dvmhost.sh - Validate setup_dvmhost.sh execution
#
# This script validates that setup_dvmhost.sh correctly:
# - Created configuration files
# - Replaced all placeholders
# - Generated valid YAML files

set -euo pipefail

SITE_TYPE="$1"
CONFIG_DIR="/opt/centrunk/configs"

echo "Validating setup_dvmhost.sh execution..."

# Check if config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
  echo "❌ Config directory not found: $CONFIG_DIR"
  exit 1
fi

# Validate based on site type
if [ "$SITE_TYPE" = "CC/VC" ]; then
  echo "Checking CC/VC configuration files..."
  
  # Check configCC.yml exists
  if [ ! -f "$CONFIG_DIR/configCC.yml" ]; then
    echo "❌ configCC.yml not found"
    exit 1
  fi
  
  # Check configVC.yml exists
  if [ ! -f "$CONFIG_DIR/configVC.yml" ]; then
    echo "❌ configVC.yml not found"
    exit 1
  fi
  
  # Check that placeholders were replaced in configCC.yml
  if grep -q '\${' "$CONFIG_DIR/configCC.yml"; then
    echo "❌ Unreplaced placeholders found in configCC.yml:"
    grep '\${' "$CONFIG_DIR/configCC.yml"
    exit 1
  fi
  
  # Check that placeholders were replaced in configVC.yml
  if grep -q '\${' "$CONFIG_DIR/configVC.yml"; then
    echo "❌ Unreplaced placeholders found in configVC.yml:"
    grep '\${' "$CONFIG_DIR/configVC.yml"
    exit 1
  fi
  
  # Verify test values are present
  if ! grep -q "TestSite" "$CONFIG_DIR/configCC.yml"; then
    echo "❌ Test site name not found in configCC.yml"
    exit 1
  fi
  
  if ! grep -q "TestSite" "$CONFIG_DIR/configVC.yml"; then
    echo "❌ Test site name not found in configVC.yml"
    exit 1
  fi
  
  echo "✓ configCC.yml valid"
  echo "✓ configVC.yml valid"
  
else
  echo "Checking Conventional configuration file..."
  
  # Check configCONVENTIONAL.yml exists
  if [ ! -f "$CONFIG_DIR/configCONVENTIONAL.yml" ]; then
    echo "❌ configCONVENTIONAL.yml not found"
    exit 1
  fi
  
  # Check that placeholders were replaced
  if grep -q '\${' "$CONFIG_DIR/configCONVENTIONAL.yml"; then
    echo "❌ Unreplaced placeholders found in configCONVENTIONAL.yml:"
    grep '\${' "$CONFIG_DIR/configCONVENTIONAL.yml"
    exit 1
  fi
  
  # Verify test values are present
  if ! grep -q "TestSite" "$CONFIG_DIR/configCONVENTIONAL.yml"; then
    echo "❌ Test site name not found in configCONVENTIONAL.yml"
    exit 1
  fi
  
  echo "✓ configCONVENTIONAL.yml valid"
fi

# Display created files
echo ""
echo "Created configuration files:"
ls -lh "$CONFIG_DIR"/*.yml

# Show sample content (first 10 lines)
echo ""
echo "Sample configuration content:"
for config_file in "$CONFIG_DIR"/*.yml; do
  echo "=== $(basename $config_file) ==="
  head -n 10 "$config_file"
  echo ""
done

echo "✅ All validations passed!"
exit 0
