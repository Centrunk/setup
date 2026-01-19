#!/usr/bin/env bash
#
# mock-systemctl.sh - Mock systemctl for testing
#
# Usage: Install as /usr/local/bin/systemctl

set -euo pipefail

echo "Creating mock systemctl..."

cat > /usr/local/bin/systemctl << 'EOF'
#!/bin/bash
echo "Mock systemctl: $@"
exit 0
EOF

chmod +x /usr/local/bin/systemctl

echo "✓ Mock systemctl installed"
