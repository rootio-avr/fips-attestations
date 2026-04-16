# Nginx FIPS Demo Image

Interactive demonstration image showcasing Nginx 1.29.1 with wolfSSL FIPS 140-3 in real-world scenarios.

## Overview

This demo image extends `cr.root.io/nginx:1.29.1-debian-bookworm-fips` with four production-ready configuration examples:

1. **Reverse Proxy** - HTTPS reverse proxy with FIPS-compliant TLS
2. **Static Webserver** - HTTPS static file serving
3. **TLS Termination** - SSL/TLS offloading for backend services
4. **Strict FIPS** - Maximum security enforcement (TLS 1.3 only)

## Building the Image

```bash
./build.sh
```

This creates the `nginx-fips-demos:latest` image with all demo configurations pre-installed.

**Prerequisites:**
- Base image must exist: `cr.root.io/nginx:1.29.1-debian-bookworm-fips`
- Build base image first if needed: `cd .. && ./build.sh`

## Demo Configurations

### 1. Reverse Proxy Demo (Default)

**Configuration:** `configs/reverse-proxy.conf`

HTTPS reverse proxy forwarding requests to a backend service (httpbin.org for demo).

**Features:**
- HTTPS frontend (TLS 1.2/1.3)
- Backend proxying with headers
- FIPS-approved ciphers
- Health check endpoint

**Run:**
```bash
docker run -d -p 443:443 --name nginx-demo nginx-fips-demos:latest
```

**Test:**
```bash
# Test proxy (requires internet connectivity)
curl -k https://localhost/get

# Health check
curl -k https://localhost/health

# View TLS details
openssl s_client -connect localhost:443 -showcerts
```

### 2. Static Webserver Demo

**Configuration:** `configs/static-webserver.conf`

HTTPS static file server with security headers and HTTP-to-HTTPS redirect.

**Features:**
- Serves static HTML content
- Security headers (X-Frame-Options, CSP, etc.)
- HTTP to HTTPS redirect
- FIPS-compliant TLS

**Run:**
```bash
docker run -d -p 80:80 -p 443:443 --name nginx-static \
  -v $(pwd)/configs/static-webserver.conf:/etc/nginx/nginx.conf:ro \
  nginx-fips-demos:latest
```

**Test:**
```bash
# Access demo page
curl -k https://localhost/

# Test HTTP redirect
curl -I http://localhost/
# Should return: HTTP/1.1 301 Moved Permanently

# Health check
curl -k https://localhost/health
```

**Customization:**
Mount your own HTML content:
```bash
docker run -d -p 443:443 \
  -v $(pwd)/configs/static-webserver.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/my-website:/usr/share/nginx/html/demos:ro \
  nginx-fips-demos:latest
```

### 3. TLS Termination Demo

**Configuration:** `configs/tls-termination.conf`

SSL/TLS offloading - terminates HTTPS connections and forwards to HTTP backends.

**Features:**
- HTTPS frontend, HTTP backend
- SSL session caching
- SSL info headers for backend
- Detailed SSL logging

**Run:**
```bash
docker run -d -p 443:443 --name nginx-tls-term \
  -v $(pwd)/configs/tls-termination.conf:/etc/nginx/nginx.conf:ro \
  nginx-fips-demos:latest
```

**Test:**
```bash
# SSL info endpoint
curl -k https://localhost/ssl-info

# View SSL details in logs
docker logs nginx-tls-term
```

**Production Setup:**
Configure backend servers in the config:
```nginx
upstream backend {
    server backend1.internal:8080;
    server backend2.internal:8080;
    server backend3.internal:8080;
}
```

### 4. Strict FIPS Demo

**Configuration:** `configs/strict-fips.conf`

Maximum FIPS enforcement with strictest security settings.

**Features:**
- **TLS 1.3 ONLY** (no TLS 1.2)
- Minimal cipher suite
- Strict security headers (HSTS, CSP, etc.)
- Session tickets disabled
- HTTPS-only (HTTP returns 426)

**Run:**
```bash
docker run -d -p 80:80 -p 443:443 --name nginx-strict \
  -v $(pwd)/configs/strict-fips.conf:/etc/nginx/nginx.conf:ro \
  nginx-fips-demos:latest
```

**Test:**
```bash
# FIPS info endpoint
curl -k https://localhost/fips-info

# Test TLS 1.3 only
openssl s_client -connect localhost:443 -tls1_3
# Should succeed

openssl s_client -connect localhost:443 -tls1_2
# Should fail (TLS 1.3 only)

# Test HTTP rejection
curl http://localhost/
# Should return: 426 HTTPS Required
```

## Configuration Comparison

| Feature | Reverse Proxy | Static Webserver | TLS Termination | Strict FIPS |
|---------|--------------|------------------|-----------------|-------------|
| **TLS Protocols** | 1.2, 1.3 | 1.2, 1.3 | 1.2, 1.3 | 1.3 only |
| **Backend** | HTTPS | Static files | HTTP | Static files |
| **HTTP Support** | No | Redirect | No | 426 Error |
| **Use Case** | API Gateway | Website | Load Balancer | High Security |
| **Security Level** | High | High | High | Maximum |

## Using Your Own SSL Certificates

All demos use self-signed certificates by default. For production, mount your own certificates:

```bash
docker run -d -p 443:443 \
  -v $(pwd)/configs/reverse-proxy.conf:/etc/nginx/nginx.conf:ro \
  -v /path/to/your/cert.crt:/etc/nginx/ssl/self-signed.crt:ro \
  -v /path/to/your/key.key:/etc/nginx/ssl/self-signed.key:ro \
  nginx-fips-demos:latest
```

**Certificate Requirements:**
- RSA key size: Minimum 2048-bit (FIPS requirement)
- Supported key types: RSA, ECDSA (P-256, P-384)
- Format: PEM-encoded

## Environment Variables

The demos can be customized using environment variables:

```bash
docker run -d -p 443:443 \
  -e NGINX_WORKER_PROCESSES=4 \
  -e NGINX_WORKER_CONNECTIONS=2048 \
  nginx-fips-demos:latest
```

*Note: Environment variable support requires modifying configs to use `envsubst`.*

## Verifying FIPS Compliance

All demos use the same FIPS-validated wolfSSL cryptographic module. Verify:

```bash
# Check wolfProvider is loaded
docker exec nginx-demo openssl list -providers

# Verify FIPS POST
docker exec nginx-demo fips-startup-check

# View supported ciphers
docker exec nginx-demo openssl ciphers -v 'ECDHE-RSA-AES256-GCM-SHA384'
```

## Accessing Demo Logs

```bash
# Access logs
docker logs nginx-demo

# Follow logs
docker logs -f nginx-demo

# Nginx error log
docker exec nginx-demo cat /var/log/nginx/error.log

# Nginx access log
docker exec nginx-demo cat /var/log/nginx/access.log
```

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 443
sudo lsof -i :443

# Use different port
docker run -d -p 8443:443 nginx-fips-demos:latest
curl -k https://localhost:8443/
```

### Configuration Test Failed

```bash
# Test nginx config before running
docker run --rm nginx-fips-demos:latest nginx -t

# Test custom config
docker run --rm \
  -v $(pwd)/my-config.conf:/etc/nginx/nginx.conf:ro \
  nginx-fips-demos:latest nginx -t
```

### SSL Handshake Errors

```bash
# Check TLS version compatibility
openssl s_client -connect localhost:443 -tls1_2 -cipher 'ECDHE-RSA-AES256-GCM-SHA384'

# View detailed handshake
openssl s_client -connect localhost:443 -debug -msg
```

### Backend Connection Issues (Reverse Proxy/TLS Termination)

```bash
# Check backend connectivity from container
docker exec nginx-demo curl -I http://backend-service:8080

# View nginx error logs
docker exec nginx-demo tail -f /var/log/nginx/error.log
```

## Customizing Configurations

### Create Your Own Demo

1. Create custom configuration:
```bash
cp configs/static-webserver.conf configs/my-custom.conf
# Edit my-custom.conf
```

2. Run with custom config:
```bash
docker run -d -p 443:443 \
  -v $(pwd)/configs/my-custom.conf:/etc/nginx/nginx.conf:ro \
  nginx-fips-demos:latest
```

### Required FIPS Settings

All custom configurations must include:

```nginx
# Minimum FIPS-compliant settings
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
ssl_prefer_server_ciphers on;
```

For maximum security (TLS 1.3 only):
```nginx
ssl_protocols TLSv1.3;
ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256';
```

## Integration with CI/CD

### Quick Health Check

```bash
# Start demo
docker run -d -p 443:443 --name nginx-test nginx-fips-demos:latest

# Wait for startup
sleep 3

# Health check
if curl -k -f https://localhost/health; then
    echo "✓ Demo healthy"
else
    echo "✗ Demo failed"
    exit 1
fi

# Cleanup
docker stop nginx-test && docker rm nginx-test
```

### FIPS Validation in Pipeline

```bash
# Verify FIPS provider is active
docker run --rm nginx-fips-demos:latest openssl list -providers | grep -q "wolfSSL Provider FIPS"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ FIPS provider active"
else
    echo "✗ FIPS provider not found"
    exit 1
fi
```

## Performance Considerations

- **TLS 1.3**: Faster handshakes (1-RTT vs 2-RTT)
- **Session Caching**: Reduces CPU overhead for repeat connections
- **HTTP/2**: Enabled by default on all HTTPS demos
- **Worker Processes**: Default `auto` (matches CPU cores)

## Security Best Practices

1. **Use TLS 1.3** when possible (strict-fips demo)
2. **Enable HSTS** for production (included in strict-fips)
3. **Disable HTTP** or redirect to HTTPS
4. **Use real certificates** from trusted CA
5. **Monitor logs** for SSL errors and attacks
6. **Update regularly** to get latest security patches

## See Also

- [Base Image Documentation](../README.md)
- [Diagnostic Test Suite](../diagnostics/README.md)
- [Basic Test Image](../diagnostics/test-images/basic-test-image/README.md)
- [Full Diagnostics](../diagnostic.sh)

## Version Information

- **Nginx**: 1.29.1
- **wolfSSL FIPS**: 5.8.2 (Certificate #4718)
- **OpenSSL**: 3.0.19
- **wolfProvider**: 1.1.0
- **Base**: Debian Bookworm Slim
- **Image**: cr.root.io/nginx:1.29.1-debian-bookworm-fips

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review base image README
3. Run full diagnostics: `../diagnostic.sh`
4. Examine Nginx logs: `docker logs <container>`
