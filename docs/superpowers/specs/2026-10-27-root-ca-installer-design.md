# Generic macOS Root CA Installer

## Scope

Accept any valid self-signed Root CA, including the existing Wiki and Plane
certificates, without a pinned fingerprint or an INSTALL confirmation prompt.
Do not support website certificates, intermediate CAs, private keys, or certificate
bundles. Accept one public X.509 certificate in PEM or DER format.

## Approach

Keep the existing Bash script and command-line interface. A configurable fingerprint
allowlist would require ongoing CA maintenance and would not meet the request to
accept arbitrary Root CAs. Removing all certificate validation would admit non-CA
certificates. Instead, remove fingerprint pinning while retaining explicit Root CA
validation.

## Processing

1. Accept --file with a readable local path or a public HTTPS URL. Preserve standard
   GitHub blob-to-raw conversion, verified HTTPS downloads, timeouts, and cleanup.
2. Use a private temporary snapshot. Reject private-key material and multiple
   certificates; parse and normalize the single certificate to PEM.
3. Require Basic Constraints CA:TRUE, matching subject and issuer, a valid
   self-signature, and current validity. If Key Usage is present, require certificate
   signing permission. Reject invalid input before requesting administrator access.
4. Display subject, validity dates, and SHA-256 fingerprint for information only.
5. With --check, exit without modifying trust settings or requesting sudo.
6. Otherwise, immediately add the validated Root CA to the macOS System Keychain
   using the existing trustRoot operation and verify the installed certificate.
   Do not read INSTALL or require a separate confirmation. sudo may still prompt
   for the user's Mac password; do not bypass operating-system authorization.

## Documentation

Describe a generic Root CA installer rather than a Wiki-only installer. Include
local Wiki and Plane examples, public GitHub online installation, --check, and
clear warnings that the selected CA is trusted system-wide without confirmation.
Explain that validation does not establish the source's trustworthiness.
Online commands use the updated script only after it is published to the public
repository; Plane examples require its public certificate to be published too.
Do not commit or push as part of this change without an explicit request.

## Verification

Run Bash syntax checks and validation-only tests against both existing certificates.
Cover PEM and DER inputs, malformed input, private keys, certificate bundles,
non-CA and intermediate certificates, invalid self-signatures, and invalid dates.
Test HTTPS and GitHub URL handling and the no-confirmation install path with mocked
network and Keychain operations where necessary. Never install test certificates
into the real System Keychain. Report any live-network test limitations explicitly.
