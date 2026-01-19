#!/usr/bin/env bash
#
# setup-boot-files.sh - Create mock boot configuration files
#
# Usage: ./setup-boot-files.sh

set -euo pipefail

echo "Creating mock boot files..."

mkdir -p /boot/firmware

# Create cmdline.txt with serial console
echo 'console=serial0,115200 console=tty1 root=/dev/mmcblk0p2' > /boot/firmware/cmdline.txt

# Create basic config.txt
cat > /boot/firmware/config.txt << 'EOF'
# Basic config
arm_64bit=1

[all]
dtparam=audio=on
EOF

echo "✓ Boot files created"
