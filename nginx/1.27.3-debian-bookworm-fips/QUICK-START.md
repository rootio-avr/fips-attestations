# Nginx 1.27.3 FIPS - Quick Start Guide

This guide helps you get started with the Nginx FIPS image in 5 minutes.

---

## Prerequisites

```bash
# 1. Docker with BuildKit
docker --version  # Should be 20.10+

# 2. wolfSSL commercial FIPS package password
# Contact wolfSSL for license and password
```

---

## Step 1: Create Password File (30 seconds)

```bash
cd nginx/1.27.3-debian-bookworm-fips

# Create password file
echo "your-wolfssl-password-here" > wolfssl_password.txt
chmod 600 wolfssl_password.txt
```

⚠️ **Important:** Replace `your-wolfssl-password-here` with your actual wolfSSL FIPS package password.

---

## Step 2: Build the Image (15-25 minutes)

```bash
# Simple build
./build.sh

# Or with custom options
./build.sh --verbose --tag my-registry/nginx-fips:latest
```

**What happens during build:**
1. Downloads and compiles OpenSSL 3.0.15
2. Downloads and compiles wolfSSL FIPS v5.8.2
3. Builds wolfProvider 1.1.0
4. Downloads and compiles Nginx 1.27.3 with wolfSSL
5. Creates minimal runtime image

**Expected output:**
```
[INFO] Build completed successfully in 1234s
✓ Nginx version verified: 1.27.3
✓ OpenSSL installation verified

Image: cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

---

## Step 3: Run the Image (10 seconds)

```bash
# Start Nginx with FIPS validation
docker run -d -p 80:80 -p 443:443 \
  --name nginx-fips \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Check logs
docker logs nginx-fips

# Expected output:
# ================================================================================
# Nginx 1.27.3 with wolfSSL FIPS 140-3 (Certificate #4718)
# ================================================================================
# ✓ FIPS POST completed successfully
# ✓ wolfProvider loaded and active
# ✓ Nginx configuration is valid
# ✓ Initialization complete. Starting Nginx...
```

---

## Step 4: Verify FIPS Mode (1 minute)

```bash
# Test 1: Check FIPS provider
docker exec nginx-fips openssl list -providers

# Expected:
#   Providers:
#     fips
#       name: wolfSSL Provider FIPS
#       version: 1.1.0
#       status: active

# Test 2: Run FIPS POST
docker exec nginx-fips fips-startup-check

# Expected:
#   FIPS 140-3 Validation: PASS

# Test 3: Test HTTPS endpoint
curl -k https://localhost/fips-status

# Expected:
#   Nginx 1.27.3 with wolfSSL FIPS 140-3 (Cert #4718)
#   Status: Active
```

---

## Step 5: Run Diagnostics (2 minutes)

```bash
# Run all diagnostic tests
./diagnostic.sh

# Expected output:
# ================================================================================
# Running Test: test-nginx-fips-status
# ================================================================================
# ✅ test-nginx-fips-status PASSED
#
# ================================================================================
# Running Test: test-nginx-tls-handshake
# ================================================================================
# ✅ test-nginx-tls-handshake PASSED
#
# ================================================================================
# TEST SUMMARY
# ================================================================================
# Total Tests:  2
# Tests Passed: 2
# Tests Failed: 0
# ✅ ALL TESTS PASSED
```

---

## Common Use Cases

### Use Case 1: Static Web Server

```bash
# Serve your HTML files
docker run -d -p 443:443 \
  -v $(pwd)/my-website:/usr/share/nginx/html:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### Use Case 2: Reverse Proxy

Create `nginx-proxy.conf`:
```nginx
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
    }
}
```

Run with custom config:
```bash
docker run -d -p 443:443 \
  -v $(pwd)/nginx-proxy.conf:/etc/nginx/conf.d/proxy.conf:ro \
  -v $(pwd)/certs:/etc/nginx/ssl:ro \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

### Use Case 3: Development Mode (Skip FIPS Checks)

```bash
# Disable FIPS validation for development
docker run -d -p 80:80 -p 443:443 \
  -e FIPS_CHECK=false \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips
```

⚠️ **Warning:** Only use FIPS_CHECK=false for development/testing. Production must have FIPS validation enabled.

---

## Troubleshooting

### Build Fails: "wolfssl_password.txt not found"

```bash
# Create password file
echo "your-password" > wolfssl_password.txt
chmod 600 wolfssl_password.txt
```

### Build Fails: "ERROR: wolfProvider not found"

This is expected during the build process if wolfProvider installation path is non-standard. The Dockerfile has fallback logic to install manually. Check build logs for "✓ wolfProvider installation completed".

### Container Won't Start: "FIPS POST failed"

```bash
# Check logs
docker logs nginx-fips

# Verify wolfSSL FIPS package integrity
docker run --rm --entrypoint="" \
  cr.root.io/nginx:1.27.3-debian-bookworm-fips \
  fips-startup-check
```

### HTTPS Handshake Fails: "no shared cipher"

Your client doesn't support FIPS-approved ciphers. Test with openssl:

```bash
# Test TLS 1.2 with FIPS cipher
openssl s_client -connect localhost:443 \
  -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384'

# Test TLS 1.3
openssl s_client -connect localhost:443 -tls1_3
```

---

## Next Steps

### Immediate (Today)
1. ✅ Build image
2. ✅ Run diagnostics
3. ✅ Test HTTPS endpoint

### Short-term (This Week)
4. Review [IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md) for completion status
5. Read [README.md](README.md) for comprehensive documentation
6. Review [patches/README.md](patches/README.md) for wolfSSL integration details

### Medium-term (Next 2-3 Weeks)
7. Complete remaining diagnostic tests (6 more)
8. Create demos-image with configuration examples
9. Generate compliance artifacts (SBOM, VEX, SLSA)
10. Write extended documentation (ARCHITECTURE.md, DEVELOPER-GUIDE.md)

### Production Readiness
11. Replace self-signed certificate with production certificates
12. Run OpenSCAP scan for STIG compliance
13. Sign image with cosign
14. Deploy to production registry

---

## File Locations

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build definition |
| `build.sh` | Build automation script |
| `docker-entrypoint.sh` | Container startup script |
| `nginx.conf.template` | FIPS-hardened Nginx configuration |
| `openssl.cnf` | wolfProvider configuration |
| `README.md` | Comprehensive documentation |
| `IMPLEMENTATION-SUMMARY.md` | Implementation status and progress |
| `diagnostics/` | Test scripts |
| `patches/README.md` | Patch information and strategy |

---

## Getting Help

### Documentation
- [README.md](README.md) - Complete user guide
- [IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md) - Project status
- [patches/README.md](patches/README.md) - wolfSSL integration details

### External Resources
- [wolfSSL FIPS Documentation](https://www.wolfssl.com/products/wolfssl-fips/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [wolfssl-nginx Repository](https://github.com/wolfSSL/wolfssl-nginx)
- [FIPS 140-3 Standard](https://csrc.nist.gov/publications/detail/fips/140/3/final)

### Support
- Open issue in your organization's issue tracker
- Contact wolfSSL support (commercial license holders)

---

## Quick Reference

```bash
# Build
./build.sh

# Run
docker run -d -p 80:80 -p 443:443 cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Test
./diagnostic.sh

# Logs
docker logs nginx-fips

# Shell
docker exec -it nginx-fips bash

# Stop
docker stop nginx-fips && docker rm nginx-fips
```

---

**Ready to build? Run:** `./build.sh`

**Need help? Read:** `README.md`

**Check status? See:** `IMPLEMENTATION-SUMMARY.md`
