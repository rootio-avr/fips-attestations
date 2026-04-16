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

1. **Base Image**: Uses `cr.root.io/fedora:44-fips` as the foundation
2. **Python Installation**: Adds Python 3.x with cryptography library
3. **FIPS Inheritance**: Inherits FIPS configuration from base image
4. **Security**: Runs as non-root user (`appuser`)

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

- **OpenSSL**: Python's cryptography library uses the system OpenSSL with FIPS provider
- **Crypto Operations**: All cryptographic operations use FIPS-approved algorithms
- **Environment**: `OPENSSL_FORCE_FIPS_MODE=1` is set in the base image
- **Verification**: Use `/opt/fips/bin/fips_init_check.sh` to verify FIPS mode

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

- **Minimal Base**: Starts with minimal FIPS base image (~317 MB)
- **Flexibility**: Add only required Python packages
- **FIPS Compliance**: Inherits FIPS configuration automatically
- **Security**: Non-root user, minimal attack surface
- **Updates**: Easy to update Python packages independently

## See Also

- [Fedora 44 FIPS Base Image](../../../README.md)
- [FIPS Diagnostics](../../README.md)
- [Node.js Example](../nodejs-app/README.md)
