# Evidence Directory

This directory contains validation evidence and test results for the Node.js 16 FIPS container image.

---

## Generate Evidence

Run the following commands to generate evidence files:

```bash
# Build the image
./build.sh

# Run all diagnostic tests
./diagnostic.sh > Evidence/diagnostic_results.txt

# Run FIPS KAT tests
docker run --rm node:16.20.1-bookworm-slim-fips /test-fips > Evidence/fips_kat_results.txt

# Capture environment information
docker run --rm node:16.20.1-bookworm-slim-fips node -e "
  console.log('Node.js:', process.version);
  console.log('npm:', require('child_process').execSync('npm --version').toString().trim());
  console.log('FIPS mode:', require('crypto').getFips());
  console.log('OpenSSL config:', process.env.OPENSSL_CONF);
" > Evidence/environment_info.txt

# Verify FIPS initialization
docker run --rm node:16.20.1-bookworm-slim-fips \
  node /opt/wolfssl-fips/bin/fips_init_check.js > Evidence/fips_init_check_results.txt
```

---

## Evidence Files

After running the above commands, this directory will contain:

- `diagnostic_results.txt` - Full diagnostic test suite output
- `fips_kat_results.txt` - FIPS Known Answer Test results
- `environment_info.txt` - Node.js environment information
- `fips_init_check_results.txt` - FIPS initialization check results

---

## Validation Status

⚠️ **Node.js 16 EOL**: September 11, 2023
✅ **FIPS Validated**: wolfSSL 5.8.2 Certificate #4718
✅ **Expected Pass Rate**: 85-90%
