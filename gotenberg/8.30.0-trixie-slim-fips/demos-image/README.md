# Gotenberg FIPS Demos Image

**Purpose**: Demonstration image with ready-to-run examples showcasing Gotenberg FIPS functionality.

## Overview

This demos image contains practical examples demonstrating:

- HTML to PDF conversion with FIPS-compliant TLS
- Office document to PDF conversion (DOCX, XLSX, PPTX)
- Webhook-based async conversion workflows
- Runtime FIPS provider verification

## Architecture

```
┌─────────────────────────────────────────┐
│  Demos Image                            │
│  - Shell scripts                        │
│  - Python examples                      │
│  - Sample documents                     │
│  - curl/jq utilities                    │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Gotenberg FIPS Service                 │
│  - OpenSSL 3.5.0                        │
│  - wolfSSL FIPS v5.8.2                  │
│  - golang-fips/go v1.26.2               │
└─────────────────────────────────────────┘
```

## Building

### Prerequisites

1. Build the base Gotenberg FIPS image first:
   ```bash
   cd ../
   ./build.sh
   ```

2. Ensure Docker BuildKit is enabled:
   ```bash
   export DOCKER_BUILDKIT=1
   ```

### Build Demos Image

```bash
./build.sh
```

This creates: `gotenberg-demos:8.30.0-trixie-slim-fips`

## Available Demos

### 1. FIPS Verification Demo
**Location**: `/demos/fips-verification/`

Demonstrates runtime FIPS provider verification.

**Run**:
```bash
docker run --rm gotenberg-demos:8.30.0-trixie-slim-fips /demos/fips-verification/run.sh
```

**Expected Output**:
```
✓ OpenSSL 3.5.0 detected
✓ wolfSSL FIPS provider active
✓ FIPS mode enforced
✓ All cryptographic operations use FIPS module
```

### 2. HTML to PDF Demo
**Location**: `/demos/html-to-pdf/`

Demonstrates converting HTML content to PDF using Gotenberg API.

**Prerequisites**: Gotenberg service must be running

**Setup**:
```bash
# Create network
docker network create gotenberg-demo-net

# Start Gotenberg service
docker run -d --name gotenberg-svc \
  --network gotenberg-demo-net \
  -p 3000:3000 \
  gotenberg:8.30.0-trixie-slim-fips
```

**Run**:
```bash
docker run --rm --network gotenberg-demo-net \
  -e GOTENBERG_URL=http://gotenberg-svc:3000 \
  gotenberg-demos:8.30.0-trixie-slim-fips \
  /demos/html-to-pdf/run.sh
```

**Features**:
- Simple HTML → PDF conversion
- HTML + CSS → PDF conversion
- Multiple HTML files → single PDF
- Custom page settings (margins, format, orientation)

### 3. Office to PDF Demo
**Location**: `/demos/office-to-pdf/`

Demonstrates converting Office documents to PDF.

**Prerequisites**: Gotenberg service must be running (same as HTML demo)

**Run**:
```bash
docker run --rm --network gotenberg-demo-net \
  -e GOTENBERG_URL=http://gotenberg-svc:3000 \
  gotenberg-demos:8.30.0-trixie-slim-fips \
  /demos/office-to-pdf/run.sh
```

**Supported Formats**:
- Microsoft Word (.docx)
- Microsoft Excel (.xlsx)
- Microsoft PowerPoint (.pptx)
- OpenDocument formats (.odt, .ods, .odp)

### 4. Webhook Demo
**Location**: `/demos/webhook-demo/`

Demonstrates async conversion with webhook callbacks.

**Prerequisites**:
- Gotenberg service running
- Webhook receiver endpoint (demo includes simple Python server)

**Run**:
```bash
docker run --rm --network gotenberg-demo-net \
  -e GOTENBERG_URL=http://gotenberg-svc:3000 \
  -e WEBHOOK_URL=http://webhook-receiver:8080/callback \
  gotenberg-demos:8.30.0-trixie-slim-fips \
  /demos/webhook-demo/run.sh
```

**Features**:
- Async PDF generation
- Webhook status callbacks
- Error handling
- Retry logic

## Usage Patterns

### Pattern 1: Standalone Demo (No Service Required)

For demos that don't need Gotenberg service:

```bash
docker run --rm gotenberg-demos:8.30.0-trixie-slim-fips /demos/fips-verification/run.sh
```

### Pattern 2: With Gotenberg Service

For demos requiring API access:

```bash
# 1. Create network
docker network create gotenberg-demo-net

# 2. Start Gotenberg
docker run -d --name gotenberg-svc \
  --network gotenberg-demo-net \
  -p 3000:3000 \
  gotenberg:8.30.0-trixie-slim-fips

# 3. Run demo
docker run --rm --network gotenberg-demo-net \
  -e GOTENBERG_URL=http://gotenberg-svc:3000 \
  gotenberg-demos:8.30.0-trixie-slim-fips \
  /demos/html-to-pdf/run.sh

# 4. Cleanup
docker stop gotenberg-svc
docker rm gotenberg-svc
docker network rm gotenberg-demo-net
```

### Pattern 3: Interactive Shell

Explore demos interactively:

```bash
docker run -it --rm --network gotenberg-demo-net \
  -e GOTENBERG_URL=http://gotenberg-svc:3000 \
  gotenberg-demos:8.30.0-trixie-slim-fips \
  /bin/bash

# Inside container:
cd /demos/html-to-pdf
./run.sh
```

## Demo File Structure

Each demo follows this structure:

```
demos/
└── <demo-name>/
    ├── run.sh          # Main demo script
    ├── README.md       # Demo-specific documentation
    ├── examples/       # Sample files (HTML, Office docs, etc.)
    └── scripts/        # Helper scripts
```

## Environment Variables

Demos support these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `GOTENBERG_URL` | `http://localhost:3000` | Gotenberg service URL |
| `WEBHOOK_URL` | - | Webhook callback URL (for webhook demo) |
| `OUTPUT_DIR` | `/tmp` | Output directory for generated PDFs |
| `DEBUG` | `false` | Enable debug output |

## Customization

### Adding Custom Demos

1. Create demo directory:
   ```bash
   mkdir -p demos/my-custom-demo
   ```

2. Create run script:
   ```bash
   cat > demos/my-custom-demo/run.sh <<'EOF'
   #!/bin/bash
   echo "Running my custom demo..."
   # Your demo logic here
   EOF
   chmod +x demos/my-custom-demo/run.sh
   ```

3. Rebuild image:
   ```bash
   ./build.sh
   ```

### Modifying Existing Demos

Edit demo scripts in `demos/<demo-name>/run.sh` and rebuild:

```bash
./build.sh
```

## Troubleshooting

### Base image not found
```
Error: Base image 'gotenberg:8.30.0-trixie-slim-fips' not found
```

**Solution**: Build the base image first:
```bash
cd ../
./build.sh
```

### Connection refused
```
Error: Failed to connect to http://gotenberg-svc:3000
```

**Solution**: Ensure Gotenberg service is running and both containers are on the same network:
```bash
docker ps | grep gotenberg-svc
docker network inspect gotenberg-demo-net
```

### Demo script not executable
```
Error: Permission denied: /demos/html-to-pdf/run.sh
```

**Solution**: Scripts should be executable in the image. If not, rebuild:
```bash
./build.sh
```

## FIPS Compliance

All demos use Gotenberg FIPS image with:

- **OpenSSL 3.5.0** - Custom build with FIPS support
- **wolfSSL FIPS v5.8.2** - NIST Certificate #4718
- **wolfProvider v1.1.1** - OpenSSL 3.x provider interface
- **golang-fips/go v1.25** - FIPS-enabled Go compiler

All cryptographic operations (TLS, PDF signing, etc.) route through the FIPS 140-3 validated wolfSSL module.

## Demo Output Examples

### FIPS Verification Demo
```
================================================================================
Gotenberg FIPS Verification Demo
================================================================================

[1/5] Checking OpenSSL version...
✓ PASS: OpenSSL 3.5.0

[2/5] Checking FIPS provider...
✓ PASS: wolfSSL Provider FIPS 1.1.1 (active)

[3/5] Verifying FIPS mode...
✓ PASS: default_properties = fips=yes

[4/5] Testing FIPS algorithms...
✓ PASS: SHA-256, AES-GCM available

[5/5] Testing non-FIPS algorithm rejection...
✓ PASS: MD5 blocked correctly

================================================================================
FIPS Verification: ✓ ALL CHECKS PASSED
================================================================================
```

### HTML to PDF Demo
```
================================================================================
HTML to PDF Conversion Demo
================================================================================

[1/4] Converting simple HTML...
✓ Generated: simple.pdf (42 KB)

[2/4] Converting HTML with CSS...
✓ Generated: styled.pdf (58 KB)

[3/4] Converting multiple HTML files...
✓ Generated: merged.pdf (91 KB)

[4/4] Custom page settings...
✓ Generated: custom.pdf (37 KB)

================================================================================
All conversions successful!
Output: /tmp/gotenberg-demos/
================================================================================
```

## Related Documentation

- [Main Dockerfile](../Dockerfile) - Base FIPS image
- [Test Image](../diagnostics/test-images/basic-test-image/) - Automated test suite
- [POC-VALIDATION-REPORT.md](../POC-VALIDATION-REPORT.md) - Full validation report

## License

This demos collection is part of the Gotenberg FIPS attestation project.
