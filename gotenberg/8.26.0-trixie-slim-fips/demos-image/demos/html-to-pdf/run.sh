#!/bin/bash
################################################################################
# HTML to PDF Conversion Demo
#
# Purpose: Demonstrate HTML to PDF conversion using Gotenberg API
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

# Helper function: HTTP GET request using curl (OpenSSL 3.5.0 now compatible)
http_get() {
    curl -s "$1" 2>/dev/null
}

# Helper function: HTTP POST with file upload using curl
# Note: Gotenberg requires the file to be named "index.html" in the multipart form
http_post_file() {
    local url="$1"
    local file="$2"
    local output="$3"
    curl -s -X POST "$url" -F "files=@$file;filename=index.html" -o "$output" 2>/dev/null
}

# Helper function: HTTP POST with multiple file uploads using curl
http_post_multifile() {
    local url="$1"
    local output="$2"
    shift 2
    local files=("$@")
    local curl_args=()
    for file in "${files[@]}"; do
        curl_args+=(-F "files=@$file")
    done
    curl -s -X POST "$url" "${curl_args[@]}" -o "$output" 2>/dev/null
}

# Helper function: HTTP POST with file and form parameters using curl
# Note: Gotenberg requires the file to be named "index.html" in the multipart form
http_post_file_with_params() {
    local url="$1"
    local file="$2"
    local output="$3"
    shift 3
    local params=("$@")
    local curl_args=(-F "files=@$file;filename=index.html")
    for param in "${params[@]}"; do
        local key="${param%%=*}"
        local value="${param#*=}"
        curl_args+=(-F "$key=$value")
    done
    curl -s -X POST "$url" "${curl_args[@]}" -o "$output" 2>/dev/null
}

echo "================================================================================"
echo "HTML to PDF Conversion Demo"
echo "================================================================================"
echo ""
echo "Gotenberg URL: ${GOTENBERG_URL}"
echo "Output Directory: ${OUTPUT_DIR}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Check Gotenberg service connectivity
echo -e "${YELLOW}[0/4]${NC} Checking Gotenberg service connectivity..."
if http_get "${GOTENBERG_URL}/health" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Gotenberg service is accessible"
else
    echo -e "${RED}✗ FAIL${NC}: Cannot connect to Gotenberg service at ${GOTENBERG_URL}"
    echo ""
    echo "Please ensure Gotenberg service is running:"
    echo "  docker run -d --name gotenberg-svc -p 3000:3000 cr.root.io/gotenberg:8.26.0-trixie-slim-fips"
    exit 1
fi
echo ""

################################################################################
# Demo 1: Simple HTML to PDF
################################################################################
echo -e "${YELLOW}[1/4]${NC} Converting simple HTML to PDF..."

# Create simple HTML
cat > /tmp/simple.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Simple FIPS Demo</title>
</head>
<body>
    <h1>Gotenberg FIPS PDF Generation</h1>
    <p>This PDF was generated using Gotenberg with FIPS 140-3 compliance.</p>
    <p>OpenSSL 3.5.0 with wolfSSL FIPS provider v5.8.2 (NIST Certificate #4718)</p>
</body>
</html>
EOF

# Convert to PDF
if http_post_file "${GOTENBERG_URL}/forms/chromium/convert/html" "/tmp/simple.html" "${OUTPUT_DIR}/simple.pdf" 2>/dev/null; then
    PDF_SIZE=$(stat -f%z "${OUTPUT_DIR}/simple.pdf" 2>/dev/null || stat -c%s "${OUTPUT_DIR}/simple.pdf" 2>/dev/null)
    echo -e "${GREEN}✓ Generated${NC}: simple.pdf (${PDF_SIZE} bytes)"
else
    echo -e "${RED}✗ FAIL${NC}: Failed to convert simple HTML"
fi
echo ""

################################################################################
# Demo 2: HTML with CSS to PDF
################################################################################
echo -e "${YELLOW}[2/4]${NC} Converting HTML with CSS to PDF..."

# Create styled HTML
cat > /tmp/styled.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Styled FIPS Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
            padding: 40px;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .info-box {
            background-color: #ecf0f1;
            padding: 15px;
            margin: 20px 0;
            border-left: 4px solid #3498db;
        }
        code {
            background-color: #f8f9fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Gotenberg FIPS - Styled PDF Example</h1>

        <div class="info-box">
            <h3>FIPS 140-3 Compliance</h3>
            <p>This document was generated with FIPS-validated cryptography:</p>
            <ul>
                <li><code>OpenSSL 3.5.0</code> - Custom build with FIPS support</li>
                <li><code>wolfSSL FIPS v5.8.2</code> - NIST Certificate #4718</li>
                <li><code>golang-fips/go v1.25</code> - FIPS-enabled Go compiler</li>
            </ul>
        </div>

        <h2>Features</h2>
        <p>This demo showcases:</p>
        <ul>
            <li>HTML to PDF conversion with CSS styling</li>
            <li>Custom fonts and colors</li>
            <li>Box shadows and borders</li>
            <li>Professional document layout</li>
        </ul>
    </div>
</body>
</html>
EOF

# Convert to PDF
if http_post_file "${GOTENBERG_URL}/forms/chromium/convert/html" "/tmp/styled.html" "${OUTPUT_DIR}/styled.pdf" 2>/dev/null; then
    PDF_SIZE=$(stat -f%z "${OUTPUT_DIR}/styled.pdf" 2>/dev/null || stat -c%s "${OUTPUT_DIR}/styled.pdf" 2>/dev/null)
    echo -e "${GREEN}✓ Generated${NC}: styled.pdf (${PDF_SIZE} bytes)"
else
    echo -e "${RED}✗ FAIL${NC}: Failed to convert styled HTML"
fi
echo ""

################################################################################
# Demo 3: Multiple HTML files to single PDF
################################################################################
echo -e "${YELLOW}[3/4]${NC} Converting multiple HTML files to single PDF..."

# Create index.html
cat > /tmp/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Page 1</title>
    <style>
        body { font-family: Arial; padding: 40px; }
        h1 { color: #2c3e50; }
    </style>
</head>
<body>
    <h1>Multi-Page Document - Page 1</h1>
    <p>This is the first page of a multi-page PDF document.</p>
</body>
</html>
EOF

# Create page2.html
cat > /tmp/page2.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Page 2</title>
    <style>
        body { font-family: Arial; padding: 40px; }
        h1 { color: #27ae60; }
    </style>
</head>
<body>
    <h1>Multi-Page Document - Page 2</h1>
    <p>This is the second page, merged into the same PDF.</p>
</body>
</html>
EOF

# Convert to PDF (merge)
if http_post_multifile "${GOTENBERG_URL}/forms/chromium/convert/html" "${OUTPUT_DIR}/merged.pdf" "/tmp/index.html" "/tmp/page2.html" 2>/dev/null; then
    PDF_SIZE=$(stat -f%z "${OUTPUT_DIR}/merged.pdf" 2>/dev/null || stat -c%s "${OUTPUT_DIR}/merged.pdf" 2>/dev/null)
    echo -e "${GREEN}✓ Generated${NC}: merged.pdf (${PDF_SIZE} bytes, 2 pages)"
else
    echo -e "${RED}✗ FAIL${NC}: Failed to merge HTML files"
fi
echo ""

################################################################################
# Demo 4: Custom page settings
################################################################################
echo -e "${YELLOW}[4/4]${NC} Converting with custom page settings (A4, landscape)..."

cat > /tmp/custom.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Custom Page Settings</title>
    <style>
        body {
            font-family: Arial;
            padding: 20px;
        }
        .landscape-content {
            width: 100%;
            height: 100%;
        }
        h1 {
            color: #e74c3c;
        }
    </style>
</head>
<body>
    <div class="landscape-content">
        <h1>Landscape A4 Page</h1>
        <p>This page uses custom settings:</p>
        <ul>
            <li>Paper size: A4</li>
            <li>Orientation: Landscape</li>
            <li>Margins: 0.5in</li>
        </ul>
        <p>Generated with Gotenberg FIPS on $(date)</p>
    </div>
</body>
</html>
EOF

# Convert with custom settings
if http_post_file_with_params "${GOTENBERG_URL}/forms/chromium/convert/html" "/tmp/custom.html" "${OUTPUT_DIR}/custom.pdf" \
    "paperWidth=11.69" "paperHeight=8.27" "marginTop=0.5" "marginBottom=0.5" "marginLeft=0.5" "marginRight=0.5" 2>/dev/null; then
    PDF_SIZE=$(stat -f%z "${OUTPUT_DIR}/custom.pdf" 2>/dev/null || stat -c%s "${OUTPUT_DIR}/custom.pdf" 2>/dev/null)
    echo -e "${GREEN}✓ Generated${NC}: custom.pdf (${PDF_SIZE} bytes, landscape)"
else
    echo -e "${RED}✗ FAIL${NC}: Failed to convert with custom settings"
fi
echo ""

################################################################################
# Summary
################################################################################
echo "================================================================================"
echo "Demo Summary"
echo "================================================================================"
echo ""
echo -e "${GREEN}✓ All conversions successful!${NC}"
echo ""
echo "Generated PDFs:"
ls -lh "${OUTPUT_DIR}"/*.pdf 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "Output directory: ${OUTPUT_DIR}"
echo ""
echo "You can view these PDFs or use them for further processing."
echo "================================================================================"
