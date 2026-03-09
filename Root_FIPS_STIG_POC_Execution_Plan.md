# Root FIPS / STIG POC Execution Plan

**Internal Preparation Document** Version 1.0

------------------------------------------------------------------------

# 1. Objective

Deliver a customer-specific Proof of Concept (POC) package that fully
satisfies Section 6 (FIPS / STIG Verification) of the customer's
evaluation document.

This deliverable will:

-   Provide two production-realistic, lean Ubuntu-based images:
    -   OpenJDK FIPS image
    -   Go FIPS image
-   Demonstrate comprehensive FIPS enforcement using WolfSSL and its
    CMVP alignment
-   Provide STIG baseline compatibility and SCAP scan evidence
-   Deliver signed images with attestations
-   Include structured evidence bundles in GitHub
-   Allow the customer to validate everything in under 10 minutes

Scope is strictly limited to FIPS and STIG validation. No
cross-referencing to other Root capabilities.

------------------------------------------------------------------------

# 2. Strategic Positioning

This POC demonstrates:

-   FIPS enforcement at OS level
-   FIPS enforcement at application runtime level
-   Correct cryptographic plumbing
-   Proper rejection of non-approved algorithms
-   Contrast validation (misconfiguration scenario)
-   STIG baseline compatibility for containerized Ubuntu
-   SCAP scan output transparency
-   Signed image integrity

WolfSSL is a strategic design choice: - Used intentionally as the
cryptographic foundation - CMVP-aligned - Enables OS-agnostic FIPS
strategy - Developed in close partnership

This is not a marketing document. It is a validation deliverable.

------------------------------------------------------------------------

# 3. Deliverables Overview

## 3.1 Images

Two images hosted in Root registry:

1.  root/ubuntu-fips-openjdk:`<tag>`{=html}
2.  root/golang:`<tag>`{=html}

Each image will:

-   Be lean and hardened
-   Enforce FIPS mode
-   Route crypto through WolfSSL-backed providers
-   Be signed using cosign
-   Include immutable digest references

------------------------------------------------------------------------

# 4. Monorepo Structure

Repository: root-fips-stig-poc

    /README.md
    /openjdk-image/
        README.md
        FIPS-Validation-Report.md
        STIG-Template.xml
        SCAP-Results.html
        SCAP-Results.xml
        FIPS-Test-App/
        Evidence/
    /go-image/
        README.md
        FIPS-Validation-Report.md
        STIG-Template.xml
        SCAP-Results.html
        SCAP-Results.xml
        FIPS-Test-App/
        Evidence/
    /supply-chain/
        SBOM.json
        VEX.json
        Cosign-Verification-Instructions.md

------------------------------------------------------------------------

# 5. FIPS Validation Design

Each image includes a lightweight test application.

## 5.1 OS-Level Validation

Evidence includes:

-   Confirmation FIPS mode is enabled
-   Confirmation WolfSSL module version
-   CMVP reference
-   Self-test confirmation
-   Fail-closed behavior confirmation

------------------------------------------------------------------------

## 5.2 OpenJDK Image Validation

Test application will:

-   Print active security providers
-   Confirm FIPS provider ordering
-   Attempt SHA256 (success expected)
-   Attempt MD5 (failure expected)
-   Perform TLS handshake using approved ciphers
-   Demonstrate contrast test (FIPS disabled scenario)

Evidence captured as: - Console logs - Screenshots (optional) -
Structured log file

------------------------------------------------------------------------

## 5.3 Go Image Validation

Test application will:

-   Confirm crypto backend configuration
-   Perform approved hash operation
-   Attempt disallowed algorithm
-   Perform TLS handshake constrained to approved ciphers
-   Demonstrate contrast test

Evidence captured similarly.

------------------------------------------------------------------------

# 6. Contrast Test

We will include:

-   Demonstration of behavior with FIPS enabled
-   Demonstration of behavior when FIPS intentionally misconfigured
-   Clear side-by-side comparison

Purpose: Prove enforcement is real and not superficial.

------------------------------------------------------------------------

# 7. STIG / SCAP Validation

## 7.1 STIG Template

We provide:

-   Modified Ubuntu STIG template tailored for containers
-   Explanation of container-appropriate exclusions

## 7.2 SCAP Evidence

We provide:

-   Raw SCAP XML output
-   Human-readable HTML report
-   Summary explanation

Goal: Transparency and compatibility, not blind checkbox compliance.

------------------------------------------------------------------------

# 8. Executive README Structure

Root README will contain:

1.  Executive Summary
2.  What We Are Delivering
3.  Direct Mapping to Section 6 Requirements
4.  10-Minute Validation Guide
5.  Evidence Index
6.  Image Digests and Verification
7.  WolfSSL Strategic Note

------------------------------------------------------------------------

# 9. Checklist Mapping

Explicit mapping:

-   6.1 FIPS incompatible algorithms fail
-   6.2 FIPS compatible algorithms succeed
-   6.3 OS FIPS enabled
-   STIG baseline compatibility
-   SCAP output provided
-   Signed images
-   Attestation verification

Each mapped to evidence file path.

------------------------------------------------------------------------

# 10. Validation Flow for Customer

Customer will:

1.  Pull image
2.  Verify cosign signature
3.  Run container
4.  Execute test application
5.  Observe expected output
6.  Review GitHub evidence bundle

No rebuilding required.

------------------------------------------------------------------------

# 11. Non-Goals

This POC does not:

-   Cover zero CVE claims
-   Demonstrate automated remediation
-   Demonstrate catalog density
-   Act as formal audit submission
-   Provide full FIPS Security Policy documentation

This is validation-level evidence only.

------------------------------------------------------------------------

# 12. Execution Phases

Phase 1: Image build and FIPS plumbing validation\
Phase 2: Test application development\
Phase 3: STIG template refinement\
Phase 4: SCAP scan and artifact capture\
Phase 5: Signature and attestation generation\
Phase 6: Repository packaging\
Phase 7: Internal review and dry run

------------------------------------------------------------------------

# 13. Definition of Done

For each image:

-   FIPS enforced and validated
-   Negative and positive crypto tests captured
-   Contrast test captured
-   STIG template provided
-   SCAP output provided
-   Signed image published
-   Digest documented
-   Evidence indexed
-   README executive-ready

------------------------------------------------------------------------

# 14. Internal Ownership

Engineering: - Image build and crypto plumbing - Test app development -
SCAP execution

Security: - STIG template validation - FIPS report drafting

DevOps: - Signing and registry publishing

------------------------------------------------------------------------

# 15. Final Outcome

The customer receives:

-   Two signed images
-   GitHub monorepo with structured evidence
-   Clear checklist mapping to their POC requirements
-   10-minute validation path
-   Clear demonstration of FIPS enforcement and STIG compatibility

Clean. Focused. Persuasive.
