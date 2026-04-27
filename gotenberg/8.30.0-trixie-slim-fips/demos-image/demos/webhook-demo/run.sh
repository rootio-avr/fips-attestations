#!/bin/bash
################################################################################
# Webhook Demo
#
# Purpose: Demonstrate async PDF conversion with webhook callbacks
#
# Requirements:
#   - Gotenberg service must be running
#   - Webhook receiver endpoint (optional - demo explains the concept)
#
# Environment Variables:
#   GOTENBERG_URL - Gotenberg service URL (default: http://localhost:3000)
#   WEBHOOK_URL - Webhook callback URL (optional)
################################################################################

set -e

# Configuration
GOTENBERG_URL="${GOTENBERG_URL:-http://localhost:3000}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "Webhook Demo - Async PDF Conversion"
echo "================================================================================"
echo ""
echo "Gotenberg URL: ${GOTENBERG_URL}"
if [ -n "${WEBHOOK_URL}" ]; then
    echo "Webhook URL: ${WEBHOOK_URL}"
else
    echo "Webhook URL: Not configured (explanation mode)"
fi
echo ""

################################################################################
# Check Gotenberg service
################################################################################
echo -e "${YELLOW}[0/3]${NC} Checking Gotenberg service connectivity..."
if curl -s "${GOTENBERG_URL}/health" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Gotenberg service is accessible"
else
    echo -e "${RED}✗ FAIL${NC}: Cannot connect to Gotenberg service at ${GOTENBERG_URL}"
    echo ""
    echo "Please ensure Gotenberg service is running:"
    echo "  docker run -d --name gotenberg-svc -p 3000:3000 cr.root.io/gotenberg:8.30.0-trixie-slim-fips"
    exit 1
fi
echo ""

################################################################################
# Demo 1: Webhook Concept
################################################################################
echo -e "${YELLOW}[1/3]${NC} Webhook concept explanation..."
echo ""
echo "What are webhooks?"
echo "  Webhooks allow Gotenberg to notify your application when a PDF conversion"
echo "  is complete, instead of waiting for the response synchronously."
echo ""
echo "Benefits:"
echo "  ${GREEN}✓${NC} Non-blocking: Your application doesn't wait for conversion"
echo "  ${GREEN}✓${NC} Scalable: Handle large batches without timeouts"
echo "  ${GREEN}✓${NC} Resilient: Gotenberg retries failed webhook calls"
echo "  ${GREEN}✓${NC} Status tracking: Receive success/failure notifications"
echo ""

################################################################################
# Demo 2: Webhook API Usage
################################################################################
echo -e "${YELLOW}[2/3]${NC} Webhook API usage..."
echo ""
echo "To use webhooks with Gotenberg:"
echo ""
echo "1. Set up a webhook receiver endpoint that accepts POST requests:"
echo "   • Must be accessible from Gotenberg service"
echo "   • Should return 200 OK status"
echo "   • Receives multipart form data with the generated PDF"
echo ""
echo "2. Include webhook parameters in your conversion request:"
echo ""
echo "   ${BLUE}curl -X POST${NC} ${GOTENBERG_URL}/forms/chromium/convert/html \\"
echo "     ${BLUE}-F${NC} 'files=@index.html' \\"
echo "     ${BLUE}-F${NC} 'webhookUrl=https://your-app.com/webhook/callback' \\"
echo "     ${BLUE}-F${NC} 'webhookErrorUrl=https://your-app.com/webhook/error' \\"
echo "     ${BLUE}-F${NC} 'webhookMethod=POST' \\"
echo "     ${BLUE}-F${NC} 'webhookErrorMethod=POST'"
echo ""
echo "3. Gotenberg will:"
echo "   • Accept the request immediately (returns 204 No Content)"
echo "   • Process the conversion asynchronously"
echo "   • POST the generated PDF to your webhookUrl"
echo "   • POST error details to webhookErrorUrl if conversion fails"
echo ""

################################################################################
# Demo 3: Example Webhook Receiver
################################################################################
echo -e "${YELLOW}[3/3]${NC} Example webhook receiver (Python)..."
echo ""
echo "Here's a simple webhook receiver in Python:"
echo ""

cat <<'PYTHON_CODE'
#!/usr/bin/env python3
"""
Simple webhook receiver for Gotenberg
Usage: python3 webhook_receiver.py
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import cgi
import os

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Parse multipart form data
        content_type = self.headers['Content-Type']
        if 'multipart/form-data' not in content_type:
            self.send_error(400, "Expected multipart/form-data")
            return

        # Parse form
        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={'REQUEST_METHOD': 'POST'}
        )

        # Get PDF file
        if 'file' in form:
            pdf_data = form['file'].file.read()
            filename = f"webhook_output_{os.getpid()}.pdf"

            with open(filename, 'wb') as f:
                f.write(pdf_data)

            print(f"✓ Received PDF: {filename} ({len(pdf_data)} bytes)")

            # Send success response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status":"received"}')
        else:
            self.send_error(400, "No PDF file in request")

    def log_message(self, format, *args):
        print(f"[WEBHOOK] {format % args}")

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), WebhookHandler)
    print("Webhook receiver listening on http://0.0.0.0:8080")
    server.serve_forever()
PYTHON_CODE

echo ""

################################################################################
# Demo 4: Testing with webhook
################################################################################
if [ -n "${WEBHOOK_URL}" ]; then
    echo -e "${YELLOW}[4/3]${NC} Testing with configured webhook..."
    echo ""

    # Create test HTML
    cat > /tmp/webhook-test.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Webhook Test</title></head>
<body>
    <h1>Webhook Conversion Test</h1>
    <p>This PDF was generated asynchronously via webhook.</p>
</body>
</html>
EOF

    echo "Sending conversion request with webhook..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${GOTENBERG_URL}/forms/chromium/convert/html" \
        -F "files=@/tmp/webhook-test.html" \
        -F "webhookUrl=${WEBHOOK_URL}" \
        -F "webhookMethod=POST" 2>&1)

    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)

    if [ "${HTTP_CODE}" = "204" ]; then
        echo -e "${GREEN}✓${NC} Request accepted (HTTP 204 No Content)"
        echo "  Gotenberg is processing the conversion asynchronously"
        echo "  The PDF will be POSTed to: ${WEBHOOK_URL}"
    else
        echo -e "${RED}✗${NC} Unexpected response: HTTP ${HTTP_CODE}"
    fi
fi
echo ""

################################################################################
# Summary
################################################################################
echo "================================================================================"
echo "Demo Summary"
echo "================================================================================"
echo ""
echo -e "${GREEN}✓ Webhook functionality explained${NC}"
echo ""
echo "Key Points:"
echo "  • Webhooks enable async, non-blocking PDF generation"
echo "  • Gotenberg sends POST requests with generated PDFs"
echo "  • Your webhook receiver must return 200 OK"
echo "  • Supports separate error webhooks for failed conversions"
echo "  • Ideal for batch processing and long-running conversions"
echo ""
echo "To test webhooks:"
echo "  1. Run the Python webhook receiver (save code above as webhook_receiver.py)"
echo "  2. Make it accessible to Gotenberg service"
echo "  3. Set WEBHOOK_URL environment variable"
echo "  4. Run this demo again"
echo ""
echo "Example full workflow:"
echo "  # Terminal 1: Start webhook receiver"
echo "  docker run -d --name webhook-receiver --network gotenberg-demo-net -p 8080:8080 python:3 python3 webhook_receiver.py"
echo ""
echo "  # Terminal 2: Run demo with webhook"
echo "  docker run --rm --network gotenberg-demo-net \\"
echo "    -e GOTENBERG_URL=http://gotenberg-svc:3000 \\"
echo "    -e WEBHOOK_URL=http://webhook-receiver:8080/callback \\"
echo "    gotenberg-demos:8.30.0-trixie-slim-fips /demos/webhook-demo/run.sh"
echo ""
echo "================================================================================"
