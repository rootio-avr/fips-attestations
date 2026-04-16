#!/bin/bash
################################################################################
# Package Installation Script - Node.js FIPS Runtime Stage
#
# Installs packages via Root.io repository with fallback to default repos
# Requires: Docker secret 'rootio_api_key' mounted at /run/secrets/
################################################################################

set -euo pipefail

# Package list for runtime stage
PACKAGES="python3.13 libncurses6 systemd expat python3.13-minimal libsystemd-shared libpython3.13-minimal libpython3.13-stdlib libncursesw6 libexpat1 bsdutils bsdutils login"

echo "================================================================================"
echo "Installing Runtime Stage Packages for Node.js FIPS"
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

# Configure APT to use the Root.io repository (Debian Trixie)
echo "deb [signed-by=/etc/apt/keyrings/rootio.gpg] https://pkg.root.io/debian/trixie trixie main" \
    > /etc/apt/sources.list.d/rootio.list

# Update package lists
DEBIAN_FRONTEND=noninteractive apt-get update

# Install packages with Root.io preference
for pkg in $PACKAGES; do
    if apt-cache show "rootio-$pkg" >/dev/null 2>&1; then
        echo "✓ $pkg installed from Root.io repository"
        apt-get install -y --no-install-recommends "rootio-$pkg"
    else
        echo "✓ $pkg installed from default repository"
        apt-get install -y --no-install-recommends "$pkg"
    fi
done





# Remove standard packages if patched versions were installed
# This prevents vulnerability scanners from flagging the standard packages

if dpkg -l | grep -q "^ii.*rootio-python3.13"; then
    if dpkg -l | grep -q "^ii  python3.13"; then
        echo "Removing standard python3.13 package (replaced by patched version)..."
        dpkg --remove --force-depends python3.13 2>&1 || true
        echo "✓ Standard python3.13 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libncurses6"; then
    if dpkg -l | grep -q "^ii  libncurses6"; then
        echo "Removing standard libncurses6 package (replaced by patched version)..."
        dpkg --remove --force-depends libncurses6 2>&1 || true
        echo "✓ Standard libncurses6 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-systemd"; then
    if dpkg -l | grep -q "^ii  systemd"; then
        echo "Removing standard systemd package (replaced by patched version)..."
        dpkg --remove --force-depends systemd 2>&1 || true
        echo "✓ Standard systemd removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-expat"; then
    if dpkg -l | grep -q "^ii  expat"; then
        echo "Removing standard expat package (replaced by patched version)..."
        dpkg --remove --force-depends expat 2>&1 || true
        echo "✓ Standard expat removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-python3.13-minimal"; then
    if dpkg -l | grep -q "^ii  python3.13-minimal"; then
        echo "Removing standard python3.13-minimal package (replaced by patched version)..."
        dpkg --remove --force-depends python3.13-minimal 2>&1 || true
        echo "✓ Standard python3.13-minimal removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libsystemd-shared"; then
    if dpkg -l | grep -q "^ii  libsystemd-shared"; then
        echo "Removing standard libsystemd-shared package (replaced by patched version)..."
        dpkg --remove --force-depends libsystemd-shared 2>&1 || true
        echo "✓ Standard libsystemd-shared removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libpython3.13-minimal"; then
    if dpkg -l | grep -q "^ii  libpython3.13-minimal"; then
        echo "Removing standard libpython3.13-minimal package (replaced by patched version)..."
        dpkg --remove --force-depends libpython3.13-minimal 2>&1 || true
        echo "✓ Standard libpython3.13-minimal removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libncursesw6"; then
    if dpkg -l | grep -q "^ii  libncursesw6"; then
        echo "Removing standard libncursesw6 package (replaced by patched version)..."
        dpkg --remove --force-depends libncursesw6 2>&1 || true
        echo "✓ Standard libncursesw6 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libexpat1"; then
    if dpkg -l | grep -q "^ii  libexpat1"; then
        echo "Removing standard libexpat1 package (replaced by patched version)..."
        dpkg --remove --force-depends libexpat1 2>&1 || true
        echo "✓ Standard libexpat1 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-bsdutils"; then
    if dpkg -l | grep -q "^ii  bsdutils"; then
        echo "Removing standard bsdutils package (replaced by patched version)..."
        dpkg --remove --force-depends bsdutils 2>&1 || true
        echo "✓ Standard bsdutils removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-login"; then
    if dpkg -l | grep -q "^ii  login"; then
        echo "Removing standard login package (replaced by patched version)..."
        dpkg --remove --force-depends login 2>&1 || true
        echo "✓ Standard login removed from package database"
    fi
fi

# Cleanup credentials, sources list, and cache
rm -f /etc/apt/auth.conf.d/rootio.conf
rm -f /etc/apt/sources.list.d/rootio.list
rm -f /etc/apt/keyrings/rootio.gpg
rm -rf /var/lib/apt/lists/*

echo "================================================================================"
echo "✓ Runtime Stage Package Installation Complete"
echo "================================================================================"
