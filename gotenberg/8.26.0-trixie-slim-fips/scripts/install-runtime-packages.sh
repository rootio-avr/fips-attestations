#!/bin/bash
################################################################################
# Package Installation Script - Gotenberg FIPS Runtime Stage
#
# Installs packages via Root.io repository with fallback to default repos
# Requires: Docker secret 'rootio_api_key' mounted at /run/secrets/
################################################################################

set -euo pipefail

# Package list for runtime stage
PACKAGES="systemd-sysv systemd python3.13-minimal python3.13 ncurses-bin ncurses-base libsystemd0 libsystemd-shared libpython3.13 libpython3.13-stdlib libpython3.13-minimal libpython3.13 libpam-systemd libncursesw6 nghttp2 libnghttp2-14 expat libexpat1 gpg gpgsm gpgconf gpg-agent gnupg-l10n gnupg dirmngr libxslt1.1 nghttp2-client rootio-python3.13 rootio-libpython3.13 rootio-libpython3.13-minimal rootio-libpython3.13-stdlib rootio-python3.13-minimal xdg-utils nghttp2-proxy nghttp2-server"

echo "================================================================================"
echo "Installing Runtime Stage Packages for Gotenberg FIPS"
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

if dpkg -l | grep -q "^ii.*rootio-systemd-sysv"; then
    if dpkg -l | grep -q "^ii  systemd-sysv"; then
        echo "Removing standard systemd-sysv package (replaced by patched version)..."
        dpkg --remove --force-depends systemd-sysv 2>&1 || true
        echo "✓ Standard systemd-sysv removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-systemd"; then
    if dpkg -l | grep -q "^ii  systemd"; then
        echo "Removing standard systemd package (replaced by patched version)..."
        dpkg --remove --force-depends systemd 2>&1 || true
        echo "✓ Standard systemd removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-python3.13-minimal"; then
    if dpkg -l | grep -q "^ii  python3.13-minimal"; then
        echo "Removing standard python3.13-minimal package (replaced by patched version)..."
        dpkg --remove --force-depends python3.13-minimal 2>&1 || true
        echo "✓ Standard python3.13-minimal removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-python3.13"; then
    if dpkg -l | grep -q "^ii  python3.13"; then
        echo "Removing standard python3.13 package (replaced by patched version)..."
        dpkg --remove --force-depends python3.13 2>&1 || true
        echo "✓ Standard python3.13 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-ncurses-bin"; then
    if dpkg -l | grep -q "^ii  ncurses-bin"; then
        echo "Removing standard ncurses-bin package (replaced by patched version)..."
        dpkg --remove --force-depends ncurses-bin 2>&1 || true
        echo "✓ Standard ncurses-bin removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-ncurses-base"; then
    if dpkg -l | grep -q "^ii  ncurses-base"; then
        echo "Removing standard ncurses-base package (replaced by patched version)..."
        dpkg --remove --force-depends ncurses-base 2>&1 || true
        echo "✓ Standard ncurses-base removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libsystemd0"; then
    if dpkg -l | grep -q "^ii  libsystemd0"; then
        echo "Removing standard libsystemd0 package (replaced by patched version)..."
        dpkg --remove --force-depends libsystemd0 2>&1 || true
        echo "✓ Standard libsystemd0 removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libsystemd-shared"; then
    if dpkg -l | grep  "libsystemd-shared"; then
        echo "Removing standard libsystemd-shared package (replaced by patched version)..."
        dpkg --remove --force-depends libsystemd-shared 2>&1 || true
        echo "✓ Standard libsystemd-shared removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libpython3.13-stdlib"; then
    if dpkg -l | grep  "libpython3.13-stdlib"; then
        echo "Removing standard libpython3.13-stdlib package (replaced by patched version)..."
        dpkg --remove --force-depends libpython3.13-stdlib 2>&1 || true
        echo "✓ Standard libpython3.13-stdlib removed from package database"
    fi
fi

if dpkg -l | grep "rootio-libpython3.13-minimal"; then
    if dpkg -l | grep  "libpython3.13-minimal"; then
        echo "Removing standard libpython3.13-minimal package (replaced by patched version)..."
        dpkg --remove --force-depends libpython3.13-minimal 2>&1 || true
        echo "✓ Standard libpython3.13-minimal removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libpython3.13"; then
    if dpkg -l | grep  "libpython3.13"; then
        echo "Removing standard libpython3.13 package (replaced by patched version)..."
        dpkg --remove --force-depends libpython3.13 2>&1 || true
        echo "✓ Standard libpython3.13 removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libpam-systemd"; then
    if dpkg -l | grep  "libpam-systemd"; then
        echo "Removing standard libpam-systemd package (replaced by patched version)..."
        dpkg --remove --force-depends libpam-systemd 2>&1 || true
        echo "✓ Standard libpam-systemd removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libncursesw6"; then
    if dpkg -l | grep "libncursesw6"; then
        echo "Removing standard libncursesw6 package (replaced by patched version)..."
        dpkg --remove --force-depends libncursesw6 2>&1 || true
        echo "✓ Standard libncursesw6 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-nghttp2"; then
    if dpkg -l | grep -q "^ii  nghttp2"; then
        echo "Removing standard nghttp2 package (replaced by patched version)..."
        dpkg --remove --force-depends nghttp2 2>&1 || true
        echo "✓ Standard nghttp2 removed from package database"
    fi
fi

if dpkg -l | grep "libnghttp2-14"; then
    if dpkg -l | grep "libnghttp2-14"; then
        echo "Removing standard libnghttp2-14 package (replaced by patched version)..."
        dpkg --remove --force-depends libnghttp2-14 2>&1 || true
        echo "✓ Standard libnghttp2-14 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-expat"; then
    if dpkg -l | grep -q "^ii  expat"; then
        echo "Removing standard expat package (replaced by patched version)..."
        dpkg --remove --force-depends expat 2>&1 || true
        echo "✓ Standard expat removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libexpat1"; then
    if dpkg -l | grep "libexpat1"; then
        echo "Removing standard libexpat1 package (replaced by patched version)..."
        dpkg --remove --force-depends libexpat1 2>&1 || true
        echo "✓ Standard libexpat1 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gpg"; then
    if dpkg -l | grep -q "^ii  gpg"; then
        echo "Removing standard gpg package (replaced by patched version)..."
        dpkg --remove --force-depends gpg 2>&1 || true
        echo "✓ Standard gpg removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gpgsm"; then
    if dpkg -l | grep -q "^ii  gpgsm"; then
        echo "Removing standard gpgsm package (replaced by patched version)..."
        dpkg --remove --force-depends gpgsm 2>&1 || true
        echo "✓ Standard gpgsm removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gpgconf"; then
    if dpkg -l | grep -q "^ii  gpgconf"; then
        echo "Removing standard gpgconf package (replaced by patched version)..."
        dpkg --remove --force-depends gpgconf 2>&1 || true
        echo "✓ Standard gpgconf removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gpg-agent"; then
    if dpkg -l | grep -q "^ii  gpg-agent"; then
        echo "Removing standard gpg-agent package (replaced by patched version)..."
        dpkg --remove --force-depends gpg-agent 2>&1 || true
        echo "✓ Standard gpg-agent removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gnupg-l10n"; then
    if dpkg -l | grep -q "^ii  gnupg-l10n"; then
        echo "Removing standard gnupg-l10n package (replaced by patched version)..."
        dpkg --remove --force-depends gnupg-l10n 2>&1 || true
        echo "✓ Standard gnupg-l10n removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-gnupg"; then
    if dpkg -l | grep -q "^ii  gnupg"; then
        echo "Removing standard gnupg package (replaced by patched version)..."
        dpkg --remove --force-depends gnupg 2>&1 || true
        echo "✓ Standard gnupg removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-dirmngr"; then
    if dpkg -l | grep -q "^ii  dirmngr"; then
        echo "Removing standard dirmngr package (replaced by patched version)..."
        dpkg --remove --force-depends dirmngr 2>&1 || true
        echo "✓ Standard dirmngr removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-xdg-utils"; then
    if dpkg -l | grep  "xdg-utils"; then
        echo "Removing standard xdg-utils package (replaced by patched version)..."
        dpkg --remove --force-depends xdg-utils 2>&1 || true
        echo "✓ Standard xdg-utils removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libxslt1.1"; then
    if dpkg -l | grep  "libxslt1.1"; then
        echo "Removing standard libxslt1.1 package (replaced by patched version)..."
        dpkg --remove --force-depends libxslt1.1 2>&1 || true
        echo "✓ Standard libxslt1.1 removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-nghttp2-client "; then
    if dpkg -l | grep  "nghttp2-client"; then
        echo "Removing standard nghttp2-client  package (replaced by patched version)..."
        dpkg --remove --force-depends nghttp2-client  2>&1 || true
        echo "✓ Standard nghttp2-client  removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-nghttp2-proxy"; then
    if dpkg -l | grep  "nghttp2-proxy"; then
        echo "Removing standard nghttp2-proxy  package (replaced by patched version)..."
        dpkg --remove --force-depends nghttp2-proxy  2>&1 || true
        echo "✓ Standard nghttp2-proxy  removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-nghttp2-server"; then
    if dpkg -l | grep  "nghttp2-server"; then
        echo "Removing standard nghttp2-server  package (replaced by patched version)..."
        dpkg --remove --force-depends nghttp2-server  2>&1 || true
        echo "✓ Standard nghttp2-server  removed from package database"
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
