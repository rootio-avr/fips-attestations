# Redis 7.2.4 Alpine FIPS - Supply Chain Security

This directory contains supply chain security documentation and verification instructions.

## Contents

- `Cosign-Verification-Instructions.md` - Instructions for verifying image signatures

## Cosign Signing

This image is signed using Sigstore's keyless signing method with ephemeral keys.

### Image Information

**Image:** `cr.root.io/redis:7.2.4-alpine-3.19-fips`
**Base:** Redis 7.2.4 on Alpine 3.19
**ECR Repository:** `root-reg/redis`
**Signing Method:** Keyless signing via Sigstore

**FIPS Components:**
- wolfSSL FIPS: 5.8.2 (Certificate #4718)
- wolfProvider: 1.1.0
- OpenSSL: 3.x
- Supported Protocols: TLS 1.2, TLS 1.3

## Quick Verification

### Verify Using Digest (Recommended)

```bash
# Get the image digest
docker pull cr.root.io/redis:7.2.4-alpine-3.19-fips
docker inspect cr.root.io/redis:7.2.4-alpine-3.19-fips --format '{{index .RepoDigests 0}}'

# Verify using cosign (replace <digest> with actual digest)
cosign verify \
  --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer-regexp '.*' \
  <redacted_root_ecr_base>/root-reg/redis@sha256:<digest>
```

### View Signature Artifacts

```bash
cosign tree cr.root.io/redis:7.2.4-alpine-3.19-fips
```

## Full Documentation

See `Cosign-Verification-Instructions.md` for complete verification procedures including:
- Prerequisites and setup
- Tag-based verification
- Digest-based verification (recommended)
- Proxy image verification
- Advanced commands
- Troubleshooting

## Transparency Log

All signatures are publicly logged in Rekor (Sigstore transparency log) for audit purposes:
- **Rekor URL**: https://rekor.sigstore.dev

## Security Considerations

1. **Always verify using digests** in production for immutability
2. **Pin specific certificate identities** when possible
3. **Automate verification** in CI/CD pipelines
4. **Monitor Rekor logs** for unexpected signing events
5. **Verify before pull** in production environments

## Additional Resources

- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Sigstore Project](https://www.sigstore.dev/)
- [Rekor Transparency Log](https://rekor.sigstore.dev/)
