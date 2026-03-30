#!/bin/bash
################################################################################
# Redis Exporter FIPS Demo - Docker Entrypoint
#
# This script runs as root at container startup to fix permissions for
# mounted volumes, then drops privileges to the redis-exporter user.
#
# This allows users to run:
#   docker run -v $(pwd)/certs:/demo/certs redis-exporter-demos ...
# without needing the --user flag.
################################################################################

set -e

# Target user and group
TARGET_USER="redis-exporter"
TARGET_UID=1001
TARGET_GID=1001

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# Fix Permissions for Mounted Volumes
################################################################################

fix_volume_permissions() {
    local dir="$1"

    # Only fix if directory exists and is not already owned by target user
    if [ -d "$dir" ]; then
        local current_owner=$(stat -c '%u' "$dir" 2>/dev/null || stat -f '%u' "$dir" 2>/dev/null)

        if [ "$current_owner" != "$TARGET_UID" ]; then
            echo -e "${YELLOW}[entrypoint]${NC} Fixing permissions for $dir (owner: UID $current_owner → $TARGET_UID)"
            chown -R ${TARGET_UID}:${TARGET_GID} "$dir" 2>/dev/null || true
        fi
    fi
}

# Fix common demo directories if they're mounted
fix_volume_permissions "/demo/certs"
fix_volume_permissions "/demo/data"
fix_volume_permissions "/demo/logs"

################################################################################
# Switch to Target User and Execute Command
################################################################################

# If no command specified, use default
if [ $# -eq 0 ]; then
    set -- "/demo/scripts/test-fips-enforcement.sh"
fi

# Drop privileges and execute command
# Use exec to replace this process with the target command
# runuser is available on Ubuntu/Debian systems
if command -v runuser >/dev/null 2>&1; then
    exec runuser -u ${TARGET_USER} -- "$@"
elif command -v su-exec >/dev/null 2>&1; then
    exec su-exec ${TARGET_USER} "$@"
elif command -v gosu >/dev/null 2>&1; then
    exec gosu ${TARGET_USER} "$@"
else
    # Fallback to su (less efficient but works everywhere)
    exec su -s /bin/bash ${TARGET_USER} -c "exec \"\$@\"" -- "$@"
fi
