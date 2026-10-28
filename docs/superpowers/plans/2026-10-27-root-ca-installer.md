# Root CA Installer Implementation Plan

> **For agentic workers:** Use subagent-driven-development or executing-plans to implement task-by-task.

**Goal:** Install any validated self-signed Root CA on macOS without an INSTALL prompt, from local files or public HTTPS/GitHub URLs.

**Architecture:** Retain the single Bash installer and private input snapshot. Replace fingerprint pinning with single-certificate parsing, CA checks and cryptographic self-signature/time verification before the existing System Keychain operation.

**Tech Stack:** macOS Bash 3.2, system LibreSSL/OpenSSL, curl, security, Python standard-library tests if needed.

## Task 1: Regression Tests and Implementation

Files: `tests/test_import_ssl.py`, `import-ssl.sh`.

- [ ] Generate temporary test certificates using OpenSSL; never persist private keys in the repository.
- [ ] Test both supplied CA files with `--check`, a generated unrelated CA in PEM and DER, malformed input, bundles, key material, leaf and intermediate certificates, invalid signature and dates.
- [ ] Isolate privileged commands and network access in the test harness, not through unsafe production environment overrides. Test install with stdin closed and assert trustRoot invocation without INSTALL. Test raw and GitHub blob URLs, download failure, HTTP rejection and --check avoiding privilege escalation.
- [ ] Run `python3 -m unittest discover -s tests -v` and record expected failures before modifying production code.
- [ ] Remove `expected` and fingerprint comparison. Parse one public certificate and normalize to PEM. Require CA:TRUE, subject equal to issuer, certificate-signing Key Usage when present, and self-signature/time verification using the system OpenSSL's supported flags. Reject bundles and private-key input. Keep secure temporary snapshot and HTTPS handling.
- [ ] Remove terminal confirmation; retain a short system-wide trust warning and sudo authorization. Generalize help and temporary directory prefix.
- [ ] Repeat `python3 -m unittest discover -s tests -v` until all tests pass; run `bash -n import-ssl.sh`.

## Task 2: Documentation

File: `README.md`.

- [ ] Rename the description to a generic macOS Root CA installer; document PEM/DER single-certificate scope and rejected certificate types.
- [ ] Provide local Plane/Wiki examples, retain public GitHub online commands and --check. Remove INSTALL instructions and fingerprint mismatch troubleshooting.
- [ ] Explain automatic trust, sudo password, trusted-source responsibility and publication requirements for changed scripts and Plane certificate.

## Task 3: Final Verification

- [ ] Run the test suite, syntax validation and `git diff --check`.
- [ ] Run `./import-ssl.sh --file ./wakumo-plan-root-ca.crt --check` and the Wiki equivalent without modifying system trust.
- [ ] Attempt public GitHub validation using the local updated script; report network limitations separately.
- [ ] Review the diff against the approved spec. Do not commit, push, or install any CA into the real Keychain.
