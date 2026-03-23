# Node.js FIPS Demos Image
# Demonstrates FIPS 140-3 capabilities with interactive examples

FROM node:16.20.1-bookworm-slim-fips

LABEL maintainer="Your Organization"
LABEL description="Node.js 16 with wolfSSL FIPS 140-3 - Demo Applications"
LABEL version="1.0.0"

# Switch to root for setup (base image runs as appuser)
USER root

# Copy demo applications
COPY demos/ /opt/demos/

# Set working directory
WORKDIR /opt/demos

# Make all demo scripts executable
RUN chmod +x *.js

# Create a menu script for easy demo selection
RUN cat > /opt/demos/menu.sh << 'EOF'
#!/bin/bash

clear
echo "======================================================================"
echo "  Node.js 16 with wolfSSL FIPS 140-3 - Demo Applications"
echo "======================================================================"
echo ""
echo "Available Demos:"
echo ""
echo "  1) Hash Algorithm Demo"
echo "     Demonstrates FIPS-approved hash algorithms (SHA-256/384/512)"
echo ""
echo "  2) TLS/SSL Client Demo"
echo "     Shows FIPS-compliant TLS 1.2/1.3 connections"
echo ""
echo "  3) Certificate Validation Demo"
echo "     Certificate chain validation and hostname verification"
echo ""
echo "  4) HTTPS Request Demo"
echo "     Various HTTPS request patterns (GET, POST, concurrent)"
echo ""
echo "  5) Run All Demos"
echo "     Execute all demos in sequence"
echo ""
echo "  0) Exit"
echo ""
echo "======================================================================"
echo ""
read -p "Select demo (0-5): " choice
echo ""

case $choice in
    1)
        node /opt/demos/hash_algorithm_demo.js
        ;;
    2)
        node /opt/demos/tls_ssl_client_demo.js
        ;;
    3)
        node /opt/demos/certificate_validation_demo.js
        ;;
    4)
        node /opt/demos/https_request_demo.js
        ;;
    5)
        echo "Running all demos..."
        echo ""
        node /opt/demos/hash_algorithm_demo.js
        echo ""
        read -p "Press Enter to continue to next demo..."
        echo ""
        node /opt/demos/tls_ssl_client_demo.js
        echo ""
        read -p "Press Enter to continue to next demo..."
        echo ""
        node /opt/demos/certificate_validation_demo.js
        echo ""
        read -p "Press Enter to continue to next demo..."
        echo ""
        node /opt/demos/https_request_demo.js
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo ""
read -p "Press Enter to continue..."
EOF

RUN chmod +x /opt/demos/menu.sh

# Switch back to non-root user for demo execution
USER appuser

# Default command shows menu
CMD ["/bin/bash", "/opt/demos/menu.sh"]
