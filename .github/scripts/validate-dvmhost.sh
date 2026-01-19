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
for pkg in git nano cmake; do
  if ! command -v $pkg &> /dev/null; then
    echo "ERROR: Package $pkg not installed"
    exit 1
  fi
done
echo "✓ Required packages installed"

# Check DVMHost was cloned
if [ ! -d /opt/dvmhost ]; then
  echo "ERROR: DVMHost directory not found"
  exit 1
fi
echo "✓ DVMHost repository cloned"

# Check build directory exists
if [ ! -d /opt/dvmhost/build ]; then
  echo "ERROR: Build directory not created"
  exit 1
fi
echo "✓ Build directory created"

# Check if CMake was run (CMakeCache.txt should exist)
if [ ! -f /opt/dvmhost/build/CMakeCache.txt ]; then
  echo "ERROR: CMake was not run successfully"
  exit 1
fi
echo "✓ CMake configuration completed"

# Check if Makefile exists
if [ ! -f /opt/dvmhost/Makefile ]; then
  echo "ERROR: Makefile not generated"
  exit 1
fi
echo "✓ Build configuration successful"

echo "All validations passed!"
