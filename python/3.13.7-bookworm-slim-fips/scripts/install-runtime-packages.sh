#!/bin/bash
################################################################################
# Package Installation Script - Python FIPS Runtime Stage
#
# Installs packages via Root.io repository with fallback to default repos
# Requires: Docker secret 'rootio_api_key' mounted at /run/secrets/
################################################################################

set -euo pipefail

# Package list for runtime stage
PACKAGES="ncurses-base libncurses6 libncursesw6 systemd expat libsystemd-shared libexpat1 bsdutils login libssl3 libffi8 libsqlite3-0 libbz2-1.0 libreadline8 liblzma5 libldap-2.5-0 libsystemd0 libudev1 dirmngr gnupg gnupg-l10n gnupg-l10n gnupg-utils gpg gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm"

echo "================================================================================"
echo "Installing Runtime Stage Packages for Python FIPS"
echo "================================================================================"

# Check if Docker secret is available
if [ ! -f "/run/secrets/rootio_api_key" ]; then
    echo "WARNING: rootio_api_key secret not available"
    echo "INFO: Skipping Root.io repository, installing from default Debian repos only"

    # Install packages from default repositories only
    DEBIAN_FRONTEND=noninteractive apt-get update
    for pkg in $PACKAGES; do
        echo "Installing $pkg from default repository.."
        apt-get install -y --no-install-recommends "$pkg" 2>&1 || true
    done

    rm -rf /var/lib/apt/lists/*
    echo "================================================================================"
    echo "✓ Runtime Stage Package Installation Complete (default packages only)"
    echo "================================================================================"
    exit 0
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

# Configure APT to use the Root.io repository (Debian Bookworm)
echo "deb [signed-by=/etc/apt/keyrings/rootio.gpg] https://pkg.root.io/debian/bookworm bookworm main" \
    > /etc/apt/sources.list.d/rootio.list

# Update package lists
DEBIAN_FRONTEND=noninteractive apt-get update

# Install packages with Root.io preference
for pkg in $PACKAGES; do
    if apt-cache show "rootio-$pkg" >/dev/null 2>&1; then
        echo "✓ $pkg installed from Root.io repository "
        apt-get install -y --no-install-recommends \
            -o Dpkg::Options::="--force-overwrite" \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            "rootio-$pkg"
    else
        echo "✓ $pkg installed from default repository "
        apt-get install -y --no-install-recommends "$pkg"
    fi
done

# Remove system packages
for pkg in $PACKAGES; do
    if dpkg -l | grep  "rootio-$pkg"; then
        if dpkg -l | grep  "$pkg"; then 
            echo "Removing standard $pkg package (replaced by patched version)..."
            dpkg --remove --force-depends $pkg 2>&1 || true
            dpkg --purge --force-depends $pkg 2>&1 || true
            echo "✓ Standard $pkg removed from package database"
        fi
    fi
done

# Remove standard packages if patched versions were installed
# This prevents vulnerability scanners from flagging the standard packages

# if dpkg -l | grep -q "^ii.*rootio-libncurses6"; then
#     if dpkg -l | grep -q "^ii  libncurses6"; then
#         echo "Removing standard libncurses6 package (replaced by patched version)..."
#         dpkg --remove --force-depends libncurses6 2>&1 || true
#         echo "✓ Standard libncurses6 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-systemd"; then
#     if dpkg -l | grep -q "^ii  systemd"; then
#         echo "Removing standard systemd package (replaced by patched version)..."
#         dpkg --remove --force-depends systemd 2>&1 || true
#         echo "✓ Standard systemd removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-expat"; then
#     if dpkg -l | grep -q "^ii  expat"; then
#         echo "Removing standard expat package (replaced by patched version)..."
#         dpkg --remove --force-depends expat 2>&1 || true
#         echo "✓ Standard expat removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libsystemd-shared"; then
#     if dpkg -l | grep -q "^ii  libsystemd-shared"; then
#         echo "Removing standard libsystemd-shared package (replaced by patched version)..."
#         dpkg --remove --force-depends libsystemd-shared 2>&1 || true
#         echo "✓ Standard libsystemd-shared removed from package database"
#     fi
# fi

# if dpkg -l | grep "rootio-libncursesw6"; then
#     if dpkg -l | grep "libncursesw6"; then
#         echo "Removing standard libncursesw6 package (replaced by patched version)..."
#         dpkg --remove --force-depends libncursesw6 2>&1 || true
#         echo "✓ Standard libncursesw6 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libexpat1"; then
#     if dpkg -l | grep -q "^ii  libexpat1"; then
#         echo "Removing standard libexpat1 package (replaced by patched version)..."
#         dpkg --remove --force-depends libexpat1 2>&1 || true
#         echo "✓ Standard libexpat1 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-bsdutils"; then
#     if dpkg -l | grep -q "^ii  bsdutils"; then
#         echo "Removing standard bsdutils package (replaced by patched version)..."
#         dpkg --remove --force-depends bsdutils 2>&1 || true
#         echo "✓ Standard bsdutils removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-login"; then
#     if dpkg -l | grep -q "^ii  login"; then
#         echo "Removing standard login package (replaced by patched version)..."
#         dpkg --remove --force-depends login 2>&1 || true
#         echo "✓ Standard login removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libssl3"; then
#     if dpkg -l | grep -q "^ii  libssl3"; then
#         echo "Removing standard libssl3 package (replaced by patched version)..."
#         dpkg --remove --force-depends libssl3 2>&1 || true
#         echo "✓ Standard libssl3 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libffi8"; then
#     if dpkg -l | grep -q "^ii  libffi8"; then
#         echo "Removing standard libffi8 package (replaced by patched version)..."
#         dpkg --remove --force-depends libffi8 2>&1 || true
#         echo "✓ Standard libffi8 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libsqlite3-0"; then
#     if dpkg -l | grep -q "^ii  libsqlite3-0"; then
#         echo "Removing standard libsqlite3-0 package (replaced by patched version)..."
#         dpkg --remove --force-depends libsqlite3-0 2>&1 || true
#         echo "✓ Standard libsqlite3-0 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libbz2-1.0"; then
#     if dpkg -l | grep -q "^ii  libbz2-1.0"; then
#         echo "Removing standard libbz2-1.0 package (replaced by patched version)..."
#         dpkg --remove --force-depends libbz2-1.0 2>&1 || true
#         echo "✓ Standard libbz2-1.0 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-libreadline8"; then
#     if dpkg -l | grep -q "^ii  libreadline8"; then
#         echo "Removing standard libreadline8 package (replaced by patched version)..."
#         dpkg --remove --force-depends libreadline8 2>&1 || true
#         echo "✓ Standard libreadline8 removed from package database"
#     fi
# fi

# if dpkg -l | grep -q "^ii.*rootio-liblzma5"; then
#     if dpkg -l | grep -q "^ii  liblzma5"; then
#         echo "Removing standard liblzma5 package (replaced by patched version)..."
#         dpkg --remove --force-depends liblzma5 2>&1 || true
#         echo "✓ Standard liblzma5 removed from package database"
#     fi
# fi

# Cleanup credentials, sources list, and cache
rm -f /etc/apt/auth.conf.d/rootio.conf
rm -f /etc/apt/sources.list.d/rootio.list
rm -f /etc/apt/keyrings/rootio.gpg
rm -rf /var/lib/apt/lists/*

echo "================================================================================"
echo "✓ Runtime Stage Package Installation Complete"
echo "================================================================================"
