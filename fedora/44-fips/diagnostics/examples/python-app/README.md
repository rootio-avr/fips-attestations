# Python on Fedora 44 FIPS Base - Multi-Stage Build Example

This example demonstrates how to build a FIPS-compliant Python application using the Fedora 44 FIPS base image.

## Quick Start

### Build the Image

```bash
cd diagnostics/examples/python-app
docker build -t my-python-fips-app .
```

### Run the Container

```bash
docker run -it --rm my-python-fips-app
```

### Verify FIPS Mode in Python

```bash
docker run -it --rm my-python-fips-app python3 -c "
from cryptography.hazmat.backends import default_backend
print('FIPS enabled:', default_backend()._fips_enabled)
"
```

## What This Example Demonstrates

1. **Base Image**: Uses `cr.root.io/fedora:44-fips` as the foundation (wolfSSL FIPS 140-3)
2. **Python Installation**: Adds Python 3.x with cryptography library
3. **FIPS Inheritance**: Inherits FIPS configuration from base image
4. **Security**: Default user is `root` (override with `--user appuser` if needed)

## Building Your Application

To use this as a template for your Python application:

1. **Create requirements.txt**:
   ```
   Flask==3.0.0
   requests==2.31.0
   cryptography==42.0.0
   ```

2. **Update Dockerfile**:
   ```dockerfile
   COPY requirements.txt ./
   RUN pip3 install --no-cache-dir -r requirements.txt
   COPY . .
   CMD ["python3", "app.py"]
   ```

3. **Build and run**:
   ```bash
   docker build -t my-app .
   docker run -p 5000:5000 my-app
   ```

## FIPS Compliance Notes

- **wolfSSL FIPS**: Base image uses wolfSSL FIPS v5.8.2 (Certificate #4718) via wolfProvider
- **OpenSSL 3.5.0**: Configured to use wolfProvider exclusively
- **Crypto Operations**: All Python cryptographic operations use FIPS-approved algorithms
- **Environment**: `OPENSSL_FORCE_FIPS_MODE=1` enforces FIPS mode
- **Verification**: Use `/opt/fips/bin/fips_init_check.sh` to verify FIPS mode (14 tests)

## Example Application Structure

```
your-app/
├── Dockerfile          # Based on this example
├── requirements.txt
├── app.py
└── src/
    └── ...
```

## Testing FIPS Compliance

```bash
# Run the FIPS verification script
docker run -it --rm my-python-fips-app /opt/fips/bin/fips_init_check.sh

# Test cryptographic operations
docker run -it --rm my-python-fips-app python3 -c "
import hashlib
print('SHA-256:', hashlib.sha256(b'test').hexdigest())
"
```

## Benefits of This Approach

- **FIPS Base**: Starts with wolfSSL FIPS 140-3 certified base image (~700 MB)
- **Flexibility**: Add only required Python packages
- **FIPS Compliance**: Inherits wolfSSL FIPS configuration automatically
- **Podman Available**: Podman 5.8.1 included for CI/CD scenarios (requires --privileged)
- **Updates**: Easy to update Python packages independently
- **Certificate #4718**: wolfSSL FIPS 140-3 validated module

## See Also

- [Fedora 44 FIPS Base Image](../../../README.md)
- [FIPS Diagnostics](../../README.md)
- [Node.js Example](../nodejs-app/README.md)
