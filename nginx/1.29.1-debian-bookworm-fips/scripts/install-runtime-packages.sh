#!/bin/bash
################################################################################
# Package Installation Script - Nginx FIPS Runtime Stage
#
# Installs packages via Root.io repository with fallback to default repos
# Requires: Docker secret 'rootio_api_key' mounted at /run/secrets/
################################################################################

set -euo pipefail

# Package list for runtime stage
PACKAGES="ca-certificates libpcre3 gettext-base zlib1g libsqlite3-0 libc6 libc-bin"

echo "================================================================================"
echo "Installing Runtime Stage Packages for Nginx FIPS"
echo "================================================================================"

# Validate Docker secret
if [ ! -f "/run/secrets/rootio_api_key" ]; then
    echo "ERROR: rootio_api_key secret not mounted at /run/secrets/rootio_api_key"
    exit 1
fi

# Initial update and install minimal dependencies
DEBIAN_FRONTEND=noninteractive apt-get update
apt-get install -y --no-install-recommends gnupg ca-certificates

# Initialize keyring and add Root.io GPG key
mkdir -p /etc/apt/keyrings
echo "LS0tLS1CRUdJTiBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCgptRE1FYWNrYjRSWUpLd1lCQkFIYVJ3OEJBUWRBWFlYeXdpUHg4N1loMmNveVN1dVg0R0N3d1czSGxRV2gzK1RzCnAydUdwL2UwSkZKdmIzUXVhVzhnUVZCVUlGSmxjRzl6YVhSdmNua2dQR0Z3ZEVCeWIyOTBMbWx2UG9pWkJCTVcKQ2dCQkZpRUVXWEdrUjBNQW9xMmF4dytCUlZzNXhrQ0xqOU1GQW1uSkcrRUNHd01GQ1FQQ1p3QUZDd2tJQndJQwpJZ0lHRlFvSkNBc0NCQllDQXdFQ0hnY0NGNEFBQ2drUVJWczV4a0NMajlPa0hRRUFyU2ZDNGFvRHcxV1c2WGg2CnlnakRYZUVhQlU5ZkdzdndBUGd5azZpUkZlWUJBSVFBVU9hQytSSVFaYWgxMjM3dTdqSEpsWHBUMVJNa2kvOHEKUWsrU3BLd0N1RGdFYWNrYjRSSUtLd1lCQkFHWFZRRUZBUUVIUU91Zk9QT1g1N1FMdnhWTXN2ZEZmei80cVlOeApMVjJ0cU0zRWdSa2t5YXRiQXdFSUI0aCtCQmdXQ2dBbUZpRUVXWEdrUjBNQW9xMmF4dytCUlZzNXhrQ0xqOU1GCkFtbkpHK0VDR3d3RkNRUENad0FBQ2drUVJWczV4a0NMajlONHpBRUF0MnRjRVpjbEFZaXBHbmMyNERsY2ZZNWkKaTdUQ3J3Z3k1UzU0bkpDQnJTRUJBT0dqVTAwOS9CSlBYbHU1MHdiMnpSVHV6S1ExdmsrTytTVnQwQzNoY21NSAo9QU1YSgotLS0tLUVORCBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCg==" | \
    base64 -d | gpg --dearmor -o /etc/apt/keyrings/rootio.gpg

# Create APT auth.conf.d entry for Root.io repository
mkdir -p /etc/apt/auth.conf.d
printf "machine pkg.root.io\nlogin root\npassword %s\n" \
    "$(cat /run/secrets/rootio_api_key)" > /etc/apt/auth.conf.d/rootio.conf
chmod 600 /etc/apt/auth.conf.d/rootio.conf

# Configure APT to use the Root.io repository
echo "deb [signed-by=/etc/apt/keyrings/rootio.gpg] https://pkg.root.io/debian/bookworm bookworm main" \
    > /etc/apt/sources.list.d/rootio.list

# Update package lists
DEBIAN_FRONTEND=noninteractive apt-get update

# Install packages with Root.io preference
for pkg in $PACKAGES; do
    if apt-cache show "rootio-$pkg" >/dev/null 2>&1; then
        echo "✓ $pkg installed from Root.io repository"
        # Special handling for libc6 to force overwrite conflicting files
        if [ "$pkg" = "libc6" ] || [ "$pkg" = "libc-bin" ]; then
            apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-overwrite" "rootio-$pkg"
        else
            apt-get install -y --no-install-recommends "rootio-$pkg"
        fi
    else
        echo "✓ $pkg installed from default repository"
        apt-get install -y --no-install-recommends "$pkg"
    fi
done

# Remove standard zlib1g if FIPS version was installed
# This prevents vulnerability scanners from flagging the standard package
if dpkg -l | grep -q "^ii.*rootio-zlib1g"; then
    if dpkg -l | grep -q "^ii.*zlib1g:amd64"; then
        echo "Removing standard zlib1g package (replaced by FIPS version)..."
        dpkg --remove --force-depends zlib1g
        echo "✓ Standard zlib1g removed from package database"
    fi
fi

# Remove standard libsqlite3-0 if patched version was installed
if dpkg -l | grep -q "^ii.*rootio-libsqlite3-0"; then
    if dpkg -l | grep -q "^ii.*libsqlite3-0:amd64"; then
        echo "Removing standard libsqlite3-0 package (replaced by patched version)..."
        dpkg --remove --force-depends libsqlite3-0
        echo "✓ Standard libsqlite3-0 removed from package database"
    fi
fi

# Remove GnuPG packages (not needed after package installation, fixes CVE-2026-24882)
echo "=========================================="
echo "Removing GnuPG packages (fixes CVE-2026-24882)"
echo "=========================================="

# Show currently installed GnuPG-related packages
echo "Currently installed GnuPG packages:"
dpkg -l | grep -E '(gnupg|gpg|dirmngr)' || echo "No GnuPG packages found"

# Remove main GnuPG packages (added missing gpgv and libgpg-error0)
for pkg in gnupg gnupg-l10n gnupg-utils gpg gpgv gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm dirmngr libgpg-error0; do
    if dpkg -l 2>/dev/null | grep -q "^..  ${pkg}"; then
        echo "Removing ${pkg}..."
        dpkg --purge --force-all ${pkg} 2>&1 || echo "Failed to remove ${pkg}"
    fi
done

# Remove GnuPG dependencies
for pkg in libassuan0 libksba8 libnpth0 libreadline8 pinentry-curses readline-common; do
    if dpkg -l 2>/dev/null | grep -q "^..  ${pkg}"; then
        echo "Removing dependency ${pkg}..."
        dpkg --purge --force-all ${pkg} 2>&1 || echo "Failed to remove ${pkg}"
    fi
done

# Final cleanup - remove ANY remaining GnuPG packages
echo "Final cleanup sweep..."
REMAINING=$(dpkg -l 2>/dev/null | grep -E '(gnupg|gpg|dirmngr)' | awk '{print $2}' || true)
if [ -n "$REMAINING" ]; then
    echo "Removing remaining packages: $REMAINING"
    for pkg in $REMAINING; do
        dpkg --purge --force-all $pkg 2>&1 || true
    done
fi

# Verify removal
echo "Remaining GnuPG packages (should be empty):"
dpkg -l | grep -E '(gnupg|gpg|dirmngr)' || echo "✓ All GnuPG packages successfully removed"
echo "=========================================="

# Remove standard glibc packages if patched version was installed (fixes CVE-2026-0861)
if dpkg -l | grep -q "^ii.*rootio-libc6"; then
    if dpkg -l | grep -q "^ii  libc6:amd64"; then
        echo "Removing standard libc6 package (replaced by patched version)..."
        dpkg --remove --force-depends libc6 2>&1 || true
        echo "✓ Standard libc6 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libc-bin"; then
    if dpkg -l | grep -q "^ii  libc-bin"; then
        echo "Removing standard libc-bin package (replaced by patched version)..."
        dpkg --remove --force-depends libc-bin 2>&1 || true
        echo "✓ Standard libc-bin removed from package database"
    fi
fi

# Remove standard libldap if patched version was installed (fixes CVE-2023-2953)

# if dpkg -l | grep -q "^ii  libldap-2.5-0:amd64"; then
#     echo "Removing standard libldap-2.5-0 package (replaced by patched version)..."
#     dpkg --remove --force-depends libldap-2.5-0 2>&1 || true
#     echo "✓ Standard libldap-2.5-0 removed from package database"
# fi


# Cleanup credentials and cache
rm -f /etc/apt/auth.conf.d/rootio.conf
rm -rf /var/lib/apt/lists/*

echo "================================================================================"
echo "✓ Runtime Stage Package Installation Complete"
echo "================================================================================"
