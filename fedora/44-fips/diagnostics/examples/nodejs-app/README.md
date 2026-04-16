# Node.js on Fedora 44 FIPS Base - Multi-Stage Build Example

This example demonstrates how to build a FIPS-compliant Node.js application using the Fedora 44 FIPS base image.

## Quick Start

### Build the Image

```bash
cd diagnostics/examples/nodejs-app
docker build -t my-nodejs-fips-app .
```

### Run the Container

```bash
docker run -it --rm my-nodejs-fips-app
```

### Verify FIPS Mode in Node.js

```bash
docker run -it --rm my-nodejs-fips-app node -e "console.log('FIPS Mode:', process.config.variables.openssl_fips)"
```

## What This Example Demonstrates

1. **Base Image**: Uses `cr.root.io/fedora:44-fips` as the foundation
2. **Node.js Installation**: Adds Node.js 22.x from NodeSource repository
3. **FIPS Inheritance**: Inherits FIPS configuration from base image
4. **Security**: Runs as non-root user (`appuser`)

## Building Your Application

To use this as a template for your Node.js application:

1. **Copy your application files**:
   ```dockerfile
   COPY package.json package-lock.json ./
   RUN npm ci --only=production
   COPY . .
   ```

2. **Set the startup command**:
   ```dockerfile
   CMD ["node", "server.js"]
   ```

3. **Build and run**:
   ```bash
   docker build -t my-app .
   docker run -p 3000:3000 my-app
   ```

## FIPS Compliance Notes

- **OpenSSL**: Node.js will use the system OpenSSL with FIPS provider
- **Crypto Operations**: All Node.js crypto operations use FIPS-approved algorithms
- **Environment**: `OPENSSL_FORCE_FIPS_MODE=1` is set in the base image
- **Verification**: Use `/opt/fips/bin/fips_init_check.sh` to verify FIPS mode

## Example Application Structure

```
your-app/
├── Dockerfile          # Based on this example
├── package.json
├── package-lock.json
├── server.js
└── src/
    └── ...
```

## Testing FIPS Compliance

```bash
# Run the FIPS verification script
docker run -it --rm my-nodejs-fips-app /opt/fips/bin/fips_init_check.sh

# Test cryptographic operations
docker run -it --rm my-nodejs-fips-app node -e "
const crypto = require('crypto');
const hash = crypto.createHash('sha256');
hash.update('test');
console.log('SHA-256:', hash.digest('hex'));
"
```

## Benefits of This Approach

- **Minimal Base**: Starts with minimal FIPS base image (~317 MB)
- **Flexibility**: Add only what your application needs
- **FIPS Compliance**: Inherits FIPS configuration automatically
- **Security**: Non-root user, minimal attack surface
- **Updates**: Easy to update Node.js version independently

## See Also

- [Fedora 44 FIPS Base Image](../../../README.md)
- [FIPS Diagnostics](../../README.md)
- [Python Example](../python-app/README.md)
