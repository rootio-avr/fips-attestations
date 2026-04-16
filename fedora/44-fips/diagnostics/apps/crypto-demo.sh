#!/bin/bash
#
# FIPS Cryptography Demo Application
# Interactive demonstration of FIPS-compliant crypto operations
#

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo "================================================================"
echo "  FIPS Cryptography Demo"
echo "  Fedora 44 - OpenSSL FIPS Provider"
echo "================================================================"
echo ""

# Demo 1: Hash Functions
echo -e "${CYAN}[1] Hash Functions${NC}"
echo "-------------------------------------------------------------------"
echo ""
echo "Input: Hello, FIPS!"
echo ""
echo -n "SHA-256: "
echo -n "Hello, FIPS!" | openssl dgst -sha256 | cut -d' ' -f2
echo -n "SHA-384: "
echo -n "Hello, FIPS!" | openssl dgst -sha384 | cut -d' ' -f2
echo -n "SHA-512: "
echo -n "Hello, FIPS!" | openssl dgst -sha512 | cut -d' ' -f2
echo ""

# Demo 2: Symmetric Encryption/Decryption
echo -e "${CYAN}[2] Symmetric Encryption (AES-256-CBC)${NC}"
echo "-------------------------------------------------------------------"
echo ""
PLAINTEXT="This is a secret message"
PASSWORD="my_secure_password"

echo "Original message: $PLAINTEXT"
echo ""

# Encrypt
echo "Encrypting..."
ENCRYPTED=$(echo -n "$PLAINTEXT" | openssl enc -aes-256-cbc -a -pbkdf2 -pass pass:"$PASSWORD")
echo "Encrypted (base64): $ENCRYPTED"
echo ""

# Decrypt
echo "Decrypting..."
DECRYPTED=$(echo -n "$ENCRYPTED" | openssl enc -d -aes-256-cbc -a -pbkdf2 -pass pass:"$PASSWORD")
echo "Decrypted message: $DECRYPTED"
echo ""

# Demo 3: HMAC
echo -e "${CYAN}[3] HMAC (Hash-based Message Authentication Code)${NC}"
echo "-------------------------------------------------------------------"
echo ""
MESSAGE="Authenticate this message"
SECRET="shared_secret_key"

echo "Message: $MESSAGE"
echo "Secret Key: $SECRET"
echo ""
echo -n "HMAC-SHA256: "
echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2
echo ""

# Demo 4: Random Number Generation
echo -e "${CYAN}[4] Random Number Generation${NC}"
echo "-------------------------------------------------------------------"
echo ""
echo "16 random bytes (hex):"
openssl rand -hex 16
echo ""
echo "32 random bytes (base64):"
openssl rand -base64 32
echo ""

# Demo 5: RSA Key Pair (generated to temp files)
echo -e "${CYAN}[5] RSA Key Generation & Digital Signature${NC}"
echo "-------------------------------------------------------------------"
echo ""

TEMP_DIR=$(mktemp -d)
PRIVATE_KEY="$TEMP_DIR/private.pem"
PUBLIC_KEY="$TEMP_DIR/public.pem"
MESSAGE_FILE="$TEMP_DIR/message.txt"
SIGNATURE_FILE="$TEMP_DIR/signature.bin"

echo "Generating RSA-2048 key pair..."
openssl genrsa -out "$PRIVATE_KEY" 2048 2>/dev/null
openssl rsa -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" 2>/dev/null
echo -e "${GREEN}✓ Generated${NC}"
echo ""

# Sign a message
echo "Signing message..."
echo "This message is signed" > "$MESSAGE_FILE"
openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$SIGNATURE_FILE" "$MESSAGE_FILE"
echo -e "${GREEN}✓ Signature created${NC}"
echo ""

# Verify signature
echo "Verifying signature..."
if openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$SIGNATURE_FILE" "$MESSAGE_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Signature verified successfully${NC}"
else
    echo -e "${RED}✗ Signature verification failed${NC}"
fi
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

# Summary
echo "================================================================"
echo "  Demo Complete"
echo "================================================================"
echo ""
echo "All operations used FIPS-approved algorithms:"
echo "  - SHA-256/384/512 for hashing"
echo "  - AES-256-CBC for encryption"
echo "  - HMAC-SHA256 for authentication"
echo "  - RSA-2048 for signatures"
echo "  - FIPS-compliant RNG for random numbers"
echo ""

exit 0
