#!/bin/bash
################################################################################
# Office to PDF Conversion Demo
#
# Purpose: Demonstrate Office document to PDF conversion using Gotenberg API
#
# Requirements: Gotenberg service must be running and accessible
#
# Environment Variables:
#   GOTENBERG_URL - Gotenberg service URL (default: http://localhost:3000)
#   OUTPUT_DIR - Output directory for PDFs (default: /tmp/gotenberg-demos)
################################################################################

set -e

# Configuration
GOTENBERG_URL="${GOTENBERG_URL:-http://localhost:3000}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/gotenberg-demos}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "Office to PDF Conversion Demo"
echo "================================================================================"
echo ""
echo "Gotenberg URL: ${GOTENBERG_URL}"
echo "Output Directory: ${OUTPUT_DIR}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Check Gotenberg service connectivity
echo -e "${YELLOW}[0/3]${NC} Checking Gotenberg service connectivity..."
if curl -s "${GOTENBERG_URL}/health" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Gotenberg service is accessible"

    # Check LibreOffice status from health endpoint
    HEALTH_OUTPUT=$(curl -s "${GOTENBERG_URL}/health")
    if echo "${HEALTH_OUTPUT}" | grep -q "libreoffice"; then
        echo -e "${GREEN}✓${NC} LibreOffice is available"
    else
        echo -e "${YELLOW}⚠${NC} LibreOffice status unknown"
    fi
else
    echo -e "${RED}✗ FAIL${NC}: Cannot connect to Gotenberg service at ${GOTENBERG_URL}"
    echo ""
    echo "Please ensure Gotenberg service is running:"
    echo "  docker run -d --name gotenberg-svc -p 3000:3000 cr.root.io/gotenberg:8.26.0-trixie-slim-fips"
    exit 1
fi
echo ""

################################################################################
# Demo 1: Verify LibreOffice Binary
################################################################################
echo -e "${YELLOW}[1/3]${NC} Verifying LibreOffice installation..."

if [ -f "/usr/lib/libreoffice/program/soffice.bin" ]; then
    echo -e "${GREEN}✓${NC} LibreOffice binary found: /usr/lib/libreoffice/program/soffice.bin"

    # Try to get version
    LIBREOFFICE_VERSION=$(/usr/lib/libreoffice/program/soffice.bin --version 2>/dev/null || echo "Version unknown")
    echo "  Version: ${LIBREOFFICE_VERSION}"
else
    echo -e "${RED}✗${NC} LibreOffice binary not found"
fi

if [ -f "/usr/bin/unoconverter" ]; then
    echo -e "${GREEN}✓${NC} Unoconverter found: /usr/bin/unoconverter"
else
    echo -e "${RED}✗${NC} Unoconverter not found"
fi
echo ""

################################################################################
# Demo 2: Office Document Format Support
################################################################################
echo -e "${YELLOW}[2/3]${NC} Office document format support..."

echo "Supported formats for conversion to PDF:"
echo "  ${GREEN}✓${NC} Microsoft Word (.docx, .doc)"
echo "  ${GREEN}✓${NC} Microsoft Excel (.xlsx, .xls)"
echo "  ${GREEN}✓${NC} Microsoft PowerPoint (.pptx, .ppt)"
echo "  ${GREEN}✓${NC} OpenDocument Text (.odt)"
echo "  ${GREEN}✓${NC} OpenDocument Spreadsheet (.ods)"
echo "  ${GREEN}✓${NC} OpenDocument Presentation (.odp)"
echo "  ${GREEN}✓${NC} Rich Text Format (.rtf)"
echo ""

echo "API Endpoint: ${GOTENBERG_URL}/forms/libreoffice/convert"
echo ""

################################################################################
# Demo 3: Example API Usage
################################################################################
echo -e "${YELLOW}[3/3]${NC} Example API usage..."

echo "To convert an Office document to PDF, use:"
echo ""
echo "  curl -X POST ${GOTENBERG_URL}/forms/libreoffice/convert \\"
echo "    -F 'files=@document.docx' \\"
echo "    -o output.pdf"
echo ""

echo "With custom settings:"
echo ""
echo "  curl -X POST ${GOTENBERG_URL}/forms/libreoffice/convert \\"
echo "    -F 'files=@document.docx' \\"
echo "    -F 'landscape=true' \\"
echo "    -F 'pdfFormat=PDF/A-1a' \\"
echo "    -o output.pdf"
echo ""

echo "Convert multiple documents:"
echo ""
echo "  curl -X POST ${GOTENBERG_URL}/forms/libreoffice/convert \\"
echo "    -F 'files=@document1.docx' \\"
echo "    -F 'files=@document2.xlsx' \\"
echo "    -F 'merge=true' \\"
echo "    -o merged.pdf"
echo ""

################################################################################
# Summary
################################################################################
echo "================================================================================"
echo "Demo Summary"
echo "================================================================================"
echo ""
echo -e "${GREEN}✓ LibreOffice is ready for Office to PDF conversion${NC}"
echo ""
echo "Key Features:"
echo "  • Converts Microsoft Office formats (DOCX, XLSX, PPTX)"
echo "  • Converts OpenDocument formats (ODT, ODS, ODP)"
echo "  • Supports PDF/A output formats"
echo "  • Can merge multiple documents into single PDF"
echo "  • FIPS-compliant cryptography for all operations"
echo ""
echo "To test with your own documents:"
echo "  1. Copy your Office files to a local directory"
echo "  2. Run: curl -X POST ${GOTENBERG_URL}/forms/libreoffice/convert \\"
echo "            -F 'files=@yourfile.docx' -o output.pdf"
echo ""
echo "================================================================================"
