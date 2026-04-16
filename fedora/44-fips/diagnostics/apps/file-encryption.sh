#!/bin/bash
#
# FIPS File Encryption Utility
# Encrypt/decrypt files using FIPS-approved algorithms
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_usage() {
    echo "Usage: $0 [encrypt|decrypt] <input_file> <output_file> [password]"
    echo ""
    echo "Examples:"
    echo "  $0 encrypt file.txt file.txt.enc mypassword"
    echo "  $0 decrypt file.txt.enc file.txt mypassword"
    echo ""
    echo "FIPS-compliant algorithm used: AES-256-CBC with PBKDF2"
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    show_usage
fi

OPERATION="$1"
INPUT_FILE="$2"
OUTPUT_FILE="$3"
PASSWORD="${4:-}"

# Validate operation
if [ "$OPERATION" != "encrypt" ] && [ "$OPERATION" != "decrypt" ]; then
    echo -e "${RED}Error: Operation must be 'encrypt' or 'decrypt'${NC}"
    show_usage
fi

# Check input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file not found: $INPUT_FILE${NC}"
    exit 1
fi

# Get password if not provided
if [ -z "$PASSWORD" ]; then
    echo -n "Enter password: "
    read -rs PASSWORD
    echo ""
    echo -n "Confirm password: "
    read -rs PASSWORD2
    echo ""

    if [ "$PASSWORD" != "$PASSWORD2" ]; then
        echo -e "${RED}Error: Passwords do not match${NC}"
        exit 1
    fi
fi

echo ""
echo "================================================================"
echo "  FIPS File Encryption Utility"
echo "================================================================"
echo ""

# Perform operation
if [ "$OPERATION" = "encrypt" ]; then
    echo "Encrypting: $INPUT_FILE -> $OUTPUT_FILE"
    echo "Algorithm: AES-256-CBC with PBKDF2"
    echo ""

    if openssl enc -aes-256-cbc -pbkdf2 -salt -in "$INPUT_FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSWORD"; then
        FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        echo ""
        echo -e "${GREEN}✓ File encrypted successfully${NC}"
        echo "  Output file: $OUTPUT_FILE"
        echo "  Size: $FILE_SIZE bytes"
    else
        echo -e "${RED}✗ Encryption failed${NC}"
        exit 1
    fi

elif [ "$OPERATION" = "decrypt" ]; then
    echo "Decrypting: $INPUT_FILE -> $OUTPUT_FILE"
    echo "Algorithm: AES-256-CBC with PBKDF2"
    echo ""

    if openssl enc -d -aes-256-cbc -pbkdf2 -in "$INPUT_FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSWORD" 2>/dev/null; then
        FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        echo ""
        echo -e "${GREEN}✓ File decrypted successfully${NC}"
        echo "  Output file: $OUTPUT_FILE"
        echo "  Size: $FILE_SIZE bytes"
    else
        echo -e "${RED}✗ Decryption failed (wrong password or corrupted file)${NC}"
        exit 1
    fi
fi

echo ""
echo "================================================================"
echo "  Operation Complete"
echo "================================================================"
echo ""

exit 0
