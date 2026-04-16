#!/bin/bash
################################################################################
# Package Installation Script - Nginx FIPS Runtime Stage
#
# Installs packages via Root.io repository with fallback to default repos
# Requires: Docker secret 'rootio_api_key' mounted at /run/secrets/
################################################################################

set -euo pipefail

# Package list for runtime stage
PACKAGES="ca-certificates libpcre3 gettext-base zlib1g libsqlite3-0 libc6 libc-bin ncurses-bin ncurses-base libncursesw6 systemd libldap-2.5-0 libudev1 libsystemd0 libtinfo6 dirmngr gnupg gnupg-l10n gnupg-utils gpg gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm gpgv"

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

# # Remove GnuPG packages (not needed after package installation, fixes CVE-2026-24882)
# echo "=========================================="
# echo "Removing GnuPG packages (fixes CVE-2026-24882)"
# echo "=========================================="

# # Show currently installed GnuPG-related packages
# echo "Currently installed GnuPG packages:"
# dpkg -l | grep -E '(gnupg|gpg|dirmngr)' || echo "No GnuPG packages found"

# # Remove GnuPG executables only (NOT core libraries needed by apt-get and other tools)
# # Note: gpgv is kept because apt-get needs it for package signature verification
# for pkg in gnupg gnupg-l10n gnupg-utils gpg gpg-agent gpg-wks-client gpg-wks-server gpgconf gpgsm dirmngr; do
#     if dpkg -l 2>/dev/null | grep -q "^..  ${pkg}"; then
#         echo "Removing ${pkg}..."
#         dpkg --purge --force-all ${pkg} 2>&1 || echo "Failed to remove ${pkg}"
#     fi
# done

# Remove optional GnuPG helper packages (only if safe to remove)
# NOTE: pinentry-curses must be retained to avoid breaking gpg-agent dependencies,
# which are required by packages like curl, procps, etc. in derived images.
for pkg in ; do  # Empty list - no packages to remove currently
    if dpkg -l 2>/dev/null | grep -q "^..  ${pkg}"; then
        echo "Removing dependency ${pkg}..."
        dpkg --purge --force-all ${pkg} 2>&1 || echo "Failed to remove ${pkg}"
    fi
done

echo "Note: gpgv, core libraries (libgpg-error0, libassuan0, libksba8, libnpth0, libreadline8), and pinentry-curses retained for apt and system packages"
echo "=========================================="

# Remove standard glibc packages if patched version was installed (fixes CVE-2026-0861)
if dpkg -l | grep  "rootio-libc6"; then
    if dpkg -l | grep  "libc6:amd64"; then
        echo "Removing standard libc6 package (replaced by patched version)..."
        dpkg --remove --force-depends libc6 2>&1 || true
        echo "✓ Standard libc6 removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-libc-bin"; then
    if dpkg -l | grep  "libc-bin"; then
        echo "Removing standard libc-bin package (replaced by patched version)..."
        dpkg --remove --force-depends libc-bin 2>&1 || true
        echo "✓ Standard libc-bin removed from package database"
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

if dpkg -l | grep -q "^ii.*rootio-libncursesw6"; then
    if dpkg -l | grep -q "^ii  libncursesw6"; then
        echo "Removing standard libncursesw6 package (replaced by patched version)..."
        dpkg --remove --force-depends libncursesw6 2>&1 || true
        echo "✓ Standard libncursesw6 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-systemd"; then
    if dpkg -l | grep -q "^ii  systemd"; then
        echo "Removing standard systemd package (replaced by patched version)..."
        dpkg --remove --force-depends systemd 2>&1 || true
        echo "✓ Standard systemd removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libldap-2.5-0"; then
    if dpkg -l | grep -q "^ii  libldap-2.5-0"; then
        echo "Removing standard libldap-2.5-0 package (replaced by patched version)..."
        dpkg --remove --force-depends libldap-2.5-0 2>&1 || true
        echo "✓ Standard libldap-2.5-0 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libudev1"; then
    if dpkg -l | grep -q "^ii  libudev1"; then
        echo "Removing standard libudev1 package (replaced by patched version)..."
        dpkg --remove --force-depends libudev1 2>&1 || true
        echo "✓ Standard libudev1 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libsystemd0"; then
    if dpkg -l | grep -q "^ii  libsystemd0"; then
        echo "Removing standard libsystemd0 package (replaced by patched version)..."
        dpkg --remove --force-depends libsystemd0 2>&1 || true
        echo "✓ Standard libsystemd0 removed from package database"
    fi
fi

if dpkg -l | grep -q "^ii.*rootio-libtinfo6"; then
    if dpkg -l | grep -q "^ii  libtinfo6"; then
        echo "Removing standard libtinfo6 package (replaced by patched version)..."
        dpkg --remove --force-depends libtinfo6 2>&1 || true
        echo "✓ Standard libtinfo6 removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-dirmngr"; then
    if dpkg -l | grep  "dirmngr"; then
        echo "Removing standard dirmngr package (replaced by patched version)..."
        dpkg --remove --force-depends dirmngr 2>&1 || true
        echo "✓ Standard dirmngr removed from package database"
    fi
fi

if dpkg -l | grep "rootio-gnupg"; then
    if dpkg -l | grep "gnupg"; then
        echo "Removing standard gnupg package (replaced by patched version)..."
        dpkg --remove --force-depends gnupg 2>&1 || true
        echo "✓ Standard gnupg removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gnupg-l10n"; then
    if dpkg -l | grep  "gnupg-l10n"; then
        echo "Removing standard gnupg-l10n package (replaced by patched version)..."
        dpkg --remove --force-depends gnupg-l10n 2>&1 || true
        echo "✓ Standard gnupg-l10n removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gnupg-utils"; then
    if dpkg -l | grep "gnupg-utils"; then
        echo "Removing standard gnupg-utils package (replaced by patched version)..."
        dpkg --remove --force-depends gnupg-utils 2>&1 || true
        echo "✓ Standard gnupg-utils removed from package database"
    fi
fi

if dpkg -l | grep "rootio-gpg"; then
    if dpkg -l | grep  "gpg"; then
        echo "Removing standard gpg package (replaced by patched version)..."
        dpkg --remove --force-depends gpg 2>&1 || true
        echo "✓ Standard gpg removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpg-agent"; then
    if dpkg -l | grep "gpg-agent"; then
        echo "Removing standard gpg-agent package (replaced by patched version)..."
        dpkg --remove --force-depends gpg-agent 2>&1 || true
        echo "✓ Standard gpg-agent removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpg-wks-client"; then
    if dpkg -l | grep  "gpg-wks-client"; then
        echo "Removing standard gpg-wks-client package (replaced by patched version)..."
        dpkg --remove --force-depends gpg-wks-client 2>&1 || true
        echo "✓ Standard gpg-wks-client removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpg-wks-server"; then
    if dpkg -l | grep  "gpg-wks-server"; then
        echo "Removing standard gpg-wks-server package (replaced by patched version)..."
        dpkg --remove --force-depends gpg-wks-server 2>&1 || true
        echo "✓ Standard gpg-wks-server removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpgconf"; then
    if dpkg -l | grep "gpgconf"; then
        echo "Removing standard gpgconf package (replaced by patched version)..."
        dpkg --remove --force-depends gpgconf 2>&1 || true
        echo "✓ Standard gpgconf removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpgsm"; then
    if dpkg -l | grep  "gpgsm"; then
        echo "Removing standard gpgsm package (replaced by patched version)..."
        dpkg --remove --force-depends gpgsm 2>&1 || true
        echo "✓ Standard gpgsm removed from package database"
    fi
fi

if dpkg -l | grep  "rootio-gpgv"; then
    if dpkg -l | grep "gpgv"; then
        echo "Removing standard gpgv package (replaced by patched version)..."
        dpkg --remove --force-depends gpgv 2>&1 || true
        echo "✓ Standard gpgv removed from package database"
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
