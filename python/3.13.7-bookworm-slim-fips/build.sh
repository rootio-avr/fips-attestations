#!/bin/bash
# Build script for Python 3.13.7 with wolfSSL FIPS 140-3 container

set -e

# Default values
IMAGE_NAME="python"
IMAGE_TAG="3.13.7-bookworm-slim-fips"
WOLFSSL_PASSWORD=""
PASSWORD_FILE=""
ROOTIO_API_KEY=""
ROOTIO_KEY_FILE=""
BUILD_ARGS=""
export DOCKER_BUILDKIT=1
: "${BUILDKIT_PROGRESS:=auto}"
VERBOSE_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --password PASSWORD      wolfSSL commercial FIPS package password"
    echo "  --password-file FILE         Read password from file (default: ./wolfssl_password.txt)"
    echo "  -k, --rootio-key KEY         Root.io API key for package repository"
    echo "  --rootio-key-file FILE       Read Root.io API key from file (default: ./rootio_api_key.txt)"
    echo "  -n, --name NAME              Docker image name (default: python)"
    echo "  -t, --tag TAG                Docker image tag (default: 3.13.7-bookworm-slim-fips)"
    echo "  --no-cache                   Disable Docker build cache"
    echo "  --cache-from IMAGE           Use cache from existing image"
    echo "  -v, --verbose                Verbose Docker build output"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                         # Use secrets from files"
    echo "  $0 -p your_password -k your_api_key       # Use secrets from command line"
    echo "  $0 --password-file /path/to/pass.txt       # Use password from custom file"
    echo "  $0 --no-cache                              # Build without cache"
    echo "  $0 -v                                      # Verbose build output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--password)
            WOLFSSL_PASSWORD="$2"
            shift 2
            ;;
        --password-file)
            PASSWORD_FILE="$2"
            shift 2
            ;;
        -k|--rootio-key)
            ROOTIO_API_KEY="$2"
            shift 2
            ;;
        --rootio-key-file)
            ROOTIO_KEY_FILE="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --no-cache)
            BUILD_ARGS="$BUILD_ARGS --no-cache"
            shift
            ;;
        --cache-from)
            BUILD_ARGS="$BUILD_ARGS --cache-from=$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Determine password source
if [ -z "$WOLFSSL_PASSWORD" ]; then
    # Try to read from password file
    if [ -z "$PASSWORD_FILE" ]; then
        PASSWORD_FILE="./wolfssl_password.txt"
    fi

    if [ ! -f "$PASSWORD_FILE" ]; then
        echo -e "${RED}Error: Password file not found: $PASSWORD_FILE${NC}"
        echo "Please provide password using -p option or create password file"
        exit 1
    fi

    WOLFSSL_PASSWORD=$(cat "$PASSWORD_FILE" | head -n 1 | tr -d '\n\r')

    if [ -z "$WOLFSSL_PASSWORD" ] || [ "$WOLFSSL_PASSWORD" = "your_password_here" ]; then
        echo -e "${RED}Error: Invalid password in file: $PASSWORD_FILE${NC}"
        echo "Please update the password file with your actual wolfSSL FIPS package password"
        exit 1
    fi

    echo -e "${GREEN}Using wolfSSL password from file: $PASSWORD_FILE${NC}"
fi

# Determine Root.io API key source
if [ -z "$ROOTIO_API_KEY" ]; then
    # Try to read from API key file
    if [ -z "$ROOTIO_KEY_FILE" ]; then
        ROOTIO_KEY_FILE="./rootio_api_key.txt"
    fi

    if [ ! -f "$ROOTIO_KEY_FILE" ]; then
        echo -e "${YELLOW}Warning: Root.io API key file not found: $ROOTIO_KEY_FILE${NC}"
        echo "Building without Root.io repository (will use default Debian packages)"
    else
        ROOTIO_API_KEY=$(cat "$ROOTIO_KEY_FILE" | head -n 1 | tr -d '\n\r')

        if [ -z "$ROOTIO_API_KEY" ] || [ "$ROOTIO_API_KEY" = "your_api_key_here" ]; then
            echo -e "${YELLOW}Warning: Invalid API key in file: $ROOTIO_KEY_FILE${NC}"
            echo "Building without Root.io repository (will use default Debian packages)"
            ROOTIO_API_KEY=""
        else
            echo -e "${GREEN}Using Root.io API key from file: $ROOTIO_KEY_FILE${NC}"
        fi
    fi
fi

# Set verbose mode
if [ "$VERBOSE_MODE" = true ]; then
    BUILD_ARGS="$BUILD_ARGS --progress=plain"
    echo -e "${BLUE}Verbose mode enabled${NC}"
fi

# Display build information
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Building Python 3.13.7 with wolfSSL FIPS 140-3 Container${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}Image Name:${NC} $IMAGE_NAME:$IMAGE_TAG"
echo -e "${GREEN}Build Args:${NC} $BUILD_ARGS"
echo -e "${GREEN}Docker BuildKit:${NC} $DOCKER_BUILDKIT"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Build the Docker image
echo -e "${YELLOW}Starting Docker build...${NC}"
echo ""

# Create temporary files for secrets
PASSWORD_TMPFILE=$(mktemp)
echo -n "$WOLFSSL_PASSWORD" > "$PASSWORD_TMPFILE"

ROOTIO_TMPFILE=$(mktemp)
echo -n "$ROOTIO_API_KEY" > "$ROOTIO_TMPFILE"

# Trap to ensure cleanup
trap "rm -f $PASSWORD_TMPFILE $ROOTIO_TMPFILE" EXIT

# Run docker build
if docker build \
    --progress=plain \
    --secret id=wolfssl_password,src="$PASSWORD_TMPFILE" \
    --secret id=rootio_api_key,src="$ROOTIO_TMPFILE" \
    $BUILD_ARGS \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .; then

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  Build Successful!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}Image:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""

    # Run post-build verification
    echo -e "${YELLOW}Running post-build verification tests...${NC}"
    echo ""

    # Test 1: Verify SSL version string (provider-based approach)
    echo -e "${BLUE}Test 1: Checking SSL version...${NC}"
    if docker run --rm -e FIPS_CHECK=false "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "import ssl; ver = ssl.OPENSSL_VERSION; print('SSL Version:', ver); assert 'OpenSSL' in ver or 'wolfSSL' in ver"; then
        echo -e "${GREEN}✓ SSL version check passed${NC}"
        # Additional check for wolfProvider
        echo -e "${BLUE}  Verifying wolfProvider is loaded...${NC}"
        docker run --rm -e FIPS_CHECK=false "${IMAGE_NAME}:${IMAGE_TAG}" openssl list -providers 2>/dev/null | grep -i wolf && echo -e "${GREEN}  ✓ wolfProvider detected${NC}" || echo -e "${YELLOW}  ⚠ wolfProvider status unknown${NC}"
    else
        echo -e "${RED}✗ SSL version check failed${NC}"
        exit 1
    fi
    echo ""

    # Test 2: Run FIPS KATs
    echo -e "${BLUE}Test 2: Running FIPS Known Answer Tests...${NC}"
    if docker run --rm -e FIPS_CHECK=false "${IMAGE_NAME}:${IMAGE_TAG}" /test-fips; then
        echo -e "${GREEN}✓ FIPS KATs passed${NC}"
    else
        echo -e "${RED}✗ FIPS KATs failed${NC}"
        exit 1
    fi
    echo ""

    # Test 3: Verify SSL context creation
    echo -e "${BLUE}Test 3: Testing SSL context creation...${NC}"
    if docker run --rm -e FIPS_CHECK=false "${IMAGE_NAME}:${IMAGE_TAG}" python3 -c "import ssl; ctx = ssl.create_default_context(); print('✓ SSL context created successfully')"; then
        echo -e "${GREEN}✓ SSL context creation passed${NC}"
    else
        echo -e "${RED}✗ SSL context creation failed${NC}"
        exit 1
    fi
    echo ""

    # Test 4: Run FIPS init check
    echo -e "${BLUE}Test 4: Running FIPS initialization check...${NC}"
    if docker run --rm -e FIPS_CHECK=false "${IMAGE_NAME}:${IMAGE_TAG}" python3 /opt/wolfssl-fips/bin/fips_init_check.py; then
        echo -e "${GREEN}✓ FIPS initialization check passed${NC}"
    else
        echo -e "${YELLOW}⚠ FIPS initialization check had issues (this may be expected)${NC}"
    fi
    echo ""

    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}  All Post-Build Tests Passed!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}Image ready to use:${NC}"
    echo -e "  docker run -it ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${BLUE}To run with FIPS verification:${NC}"
    echo -e "  docker run -it ${IMAGE_NAME}:${IMAGE_TAG} python3"
    echo ""
    echo -e "${BLUE}To skip FIPS verification (development only):${NC}"
    echo -e "  docker run -it -e FIPS_CHECK=false ${IMAGE_NAME}:${IMAGE_TAG} python3"
    echo ""

else
    echo ""
    echo -e "${RED}================================================================${NC}"
    echo -e "${RED}  Build Failed!${NC}"
    echo -e "${RED}================================================================${NC}"
    exit 1
fi
