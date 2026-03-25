#!/bin/bash
################################################################################
# Build script for Nginx 1.27.3 FIPS Image (Debian Bookworm)
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --no-cache          Build without Docker cache
#   --verbose           Enable verbose output
#   -t, --tag TAG       Custom image tag (default: cr.root.io/nginx:1.27.3-debian-bookworm-fips)
#   -h, --help          Show this help message
#
# Prerequisites:
#   - Docker with BuildKit enabled
#   - wolfssl_password.txt file with FIPS package password
#
################################################################################

set -euo pipefail

# Default configuration
IMAGE_TAG="${IMAGE_TAG:-cr.root.io/nginx:1.27.3-debian-bookworm-fips}"
NO_CACHE=""
VERBOSE=""
PASSWORD_FILE="wolfssl_password.txt"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    head -n 20 "$0" | grep "^#" | sed 's/^# \?//'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --verbose)
            VERBOSE="--progress=plain"
            shift
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate prerequisites
log_info "Validating prerequisites..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

if [[ ! -f "$PASSWORD_FILE" ]]; then
    log_error "wolfSSL password file not found: $PASSWORD_FILE"
    echo ""
    echo "Create password file:"
    echo "  echo 'your-wolfssl-password' > $PASSWORD_FILE"
    echo "  chmod 600 $PASSWORD_FILE"
    exit 1
fi

# Check Docker BuildKit
if [[ -z "${DOCKER_BUILDKIT:-}" ]] && [[ "$(docker version -f '{{.Server.Version}}')" < "23.0" ]]; then
    log_warn "Docker BuildKit is not enabled. Enabling for this build..."
    export DOCKER_BUILDKIT=1
fi

log_info "Starting build for: $IMAGE_TAG"
log_info "Build options: NO_CACHE=$NO_CACHE VERBOSE=$VERBOSE"

# Build the image
log_info "Building Nginx 1.27.3 FIPS image..."

BUILD_START=$(date +%s)

# shellcheck disable=SC2086
docker build \
    $NO_CACHE \
    $VERBOSE \
    --secret id=wolfssl_password,src="$PASSWORD_FILE" \
    --tag "$IMAGE_TAG" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg VCS_REF="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    .

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

log_info "Build completed successfully in ${BUILD_DURATION}s"

# Display image information
log_info "Image details:"
docker images "$IMAGE_TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Verify image
log_info "Verifying image..."
if docker run --rm --entrypoint="" "$IMAGE_TAG" nginx -v 2>&1 | grep -q "1.27.3"; then
    log_info "✓ Nginx version verified: 1.27.3"
else
    log_warn "⚠ Could not verify Nginx version"
fi

if docker run --rm --entrypoint="" "$IMAGE_TAG" openssl version 2>&1 | grep -q "OpenSSL"; then
    log_info "✓ OpenSSL installation verified"
else
    log_warn "⚠ Could not verify OpenSSL installation"
fi

# Success message
echo ""
log_info "==================== BUILD SUCCESSFUL ===================="
echo ""
echo "Image: $IMAGE_TAG"
echo ""
echo "Next steps:"
echo "  1. Run FIPS validation:"
echo "     docker run --rm $IMAGE_TAG"
echo ""
echo "  2. Run diagnostics:"
echo "     ./diagnostic.sh"
echo ""
echo "  3. Interactive shell:"
echo "     docker run --rm -it $IMAGE_TAG bash"
echo ""
log_info "=========================================================="
