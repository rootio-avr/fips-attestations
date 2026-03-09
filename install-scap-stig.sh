#!/bin/bash
set -euo pipefail

################################################################################
# Install SCAP Security Guide v0.1.74 (with STIG profile support)
# One-time installation on the host machine
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "SCAP Security Guide v0.1.74 Installer"
echo "=========================================="
echo ""
echo "This script will install SCAP Security Guide v0.1.74"
echo "which includes DISA STIG profile support for Ubuntu 22.04"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ ERROR: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

# Configuration
SCAP_VERSION="0.1.74"
DOWNLOAD_URL="https://github.com/ComplianceAsCode/content/releases/download/v${SCAP_VERSION}/scap-security-guide-${SCAP_VERSION}.zip"
INSTALL_DIR="/usr/share/xml/scap/ssg/content"
TEMP_DIR="/tmp/scap-install-$$"

################################################################################
# Step 1: Check Current Installation
################################################################################
echo -e "${BLUE}[INFO]${NC} Checking current SCAP installation..."

if [ -f "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" ]; then
    CURRENT_VERSION=$(grep -o 'version="[0-9.]*"' "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")
    echo -e "${YELLOW}⚠${NC}  Existing SCAP content found: version ${CURRENT_VERSION}"

    # Check if STIG profile exists
    if grep -q "xccdf_org.ssgproject.content_profile_stig" "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} STIG profile already exists in current installation"
        echo ""
        read -p "Do you want to reinstall v0.1.74 anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
    else
        echo -e "${YELLOW}⚠${NC}  STIG profile NOT found in current installation"
        echo -e "${BLUE}[INFO]${NC} Upgrading to v0.1.74 to add STIG support..."
    fi
else
    echo -e "${BLUE}[INFO]${NC} No existing SCAP content found"
fi

################################################################################
# Step 2: Install Prerequisites
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Installing prerequisites..."

apt-get update -qq
apt-get install -y -qq wget unzip ca-certificates || {
    echo -e "${RED}✗ ERROR: Failed to install prerequisites${NC}"
    exit 1
}

echo -e "${GREEN}✓${NC} Prerequisites installed"

################################################################################
# Step 3: Download SCAP Security Guide v0.1.74
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Downloading SCAP Security Guide v${SCAP_VERSION}..."

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

wget --no-check-certificate -q --show-progress "${DOWNLOAD_URL}" -O scap-security-guide.zip || {
    echo -e "${RED}✗ ERROR: Failed to download SCAP Security Guide${NC}"
    echo "URL: ${DOWNLOAD_URL}"
    rm -rf "$TEMP_DIR"
    exit 1
}

echo -e "${GREEN}✓${NC} Downloaded $(du -h scap-security-guide.zip | cut -f1)"

################################################################################
# Step 4: Extract and Install
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Extracting SCAP content..."

unzip -q scap-security-guide.zip || {
    echo -e "${RED}✗ ERROR: Failed to extract archive${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
}

# Find the Ubuntu 22.04 data stream file
DATASTREAM_FILE=$(find . -name "ssg-ubuntu2204-ds.xml" -type f)
if [ -z "$DATASTREAM_FILE" ]; then
    echo -e "${RED}✗ ERROR: ssg-ubuntu2204-ds.xml not found in archive${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found: $DATASTREAM_FILE"

# Backup existing content if present
if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR 2>/dev/null)" ]; then
    BACKUP_DIR="/usr/share/xml/scap/ssg/content.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${BLUE}[INFO]${NC} Backing up existing content to: ${BACKUP_DIR}"
    mkdir -p "$(dirname "$BACKUP_DIR")"
    cp -r "$INSTALL_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}✓${NC} Backup created"
fi

# Install new content
echo -e "${BLUE}[INFO]${NC} Installing to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"

cp "$DATASTREAM_FILE" "${INSTALL_DIR}/" || {
    echo -e "${RED}✗ ERROR: Failed to copy data stream file${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
}

# Also copy OVAL file if it exists
OVAL_FILE=$(find . -name "ssg-ubuntu2204-oval.xml" -type f)
if [ -n "$OVAL_FILE" ]; then
    cp "$OVAL_FILE" "${INSTALL_DIR}/" 2>/dev/null || true
fi

echo -e "${GREEN}✓${NC} SCAP content installed"

################################################################################
# Step 5: Verify Installation
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Verifying installation..."

if [ ! -f "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" ]; then
    echo -e "${RED}✗ ERROR: Installation verification failed${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check version
INSTALLED_VERSION=$(grep -o 'version="[0-9.]*"' "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")
echo -e "${GREEN}✓${NC} Installed version: ${INSTALLED_VERSION}"

# Check for STIG profile
if grep -q "xccdf_org.ssgproject.content_profile_stig" "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml"; then
    echo -e "${GREEN}✓${NC} DISA STIG profile: AVAILABLE"
else
    echo -e "${RED}✗${NC} DISA STIG profile: NOT FOUND"
fi

# Check for CIS profiles
CIS_COUNT=$(grep -c "xccdf_org.ssgproject.content_profile_cis" "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" 2>/dev/null || echo "0")
echo -e "${GREEN}✓${NC} CIS profiles: ${CIS_COUNT} found"

# List all available profiles
echo ""
echo -e "${BLUE}[INFO]${NC} Available profiles:"
if command -v oscap &> /dev/null; then
    oscap info "${INSTALL_DIR}/ssg-ubuntu2204-ds.xml" 2>/dev/null | grep "Title:" | head -10
else
    echo "  (Install libopenscap8 to list profiles)"
fi

################################################################################
# Cleanup
################################################################################
echo ""
echo -e "${BLUE}[INFO]${NC} Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓${NC} Cleanup complete"

################################################################################
# Summary
################################################################################
echo ""
echo "=========================================="
echo -e "${GREEN}Installation Complete${NC}"
echo "=========================================="
echo ""
echo "SCAP Security Guide v${SCAP_VERSION} has been installed"
echo "Location: ${INSTALL_DIR}/ssg-ubuntu2204-ds.xml"
echo ""
echo "You can now run STIG compliance scans using:"
echo "  ./scan-internal.sh amazon-k8s-cni-init:v1.21.1-ubuntu-22.04-fips-hardened"
echo ""
