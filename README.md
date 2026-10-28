# macOS Root CA Installer

`import-ssl.sh` installs and trusts a public, self-signed Root CA in the macOS System Keychain, including the Wakumo Wiki and Plane/Headscale Root CAs. It accepts one certificate in PEM or DER format, from a local file or a public HTTPS URL.

The script validates the certificate and installs it **without an `INSTALL` confirmation prompt**. macOS may still require your administrator password through `sudo`.

Website certificates, intermediate CAs, certificate bundles, and private keys are not supported.

## Requirements

- macOS with administrator privileges.
- Internet access to download the installer and certificate from GitHub.
- A connection to the company Headscale network if required by the website you want to access (not required just to import a local CA).

## Quick Install

Run this command in Terminal. **No cloning or manual downloads are required:**

```bash
(base=https://raw.githubusercontent.com/wakumo/import-certificate/main; bash <(curl -fsSL "$base/import-ssl.sh") --file "$base/wakumo-wiki-root-ca.crt")
```

> **Warning**
> This command downloads and executes a script from this repository. Only run it if you trust the repository owner and its contents.

For Plane/Headscale, use:

```bash
(base=https://raw.githubusercontent.com/wakumo/import-certificate/main; bash <(curl -fsSL "$base/import-ssl.sh") --file "$base/wakumo-plan-root-ca.crt")
```

These commands use the version published on GitHub, not your local script. Publish the updated `import-ssl.sh` to `main` before using the new behavior online. The Plane command also requires `wakumo-plan-root-ca.crt` to be published in the public repository. Local edits alone do not update either URL.

### Complete the Installation

1. Enter your **Mac login password** if prompted by `sudo`; there is no separate confirmation step.
2. Wait for `Root CA installed and verified`.
3. Fully quit your browser using **Cmd + Q**, then reopen it.
4. Connect to Headscale if required and open the relevant website, such as **https://wiki.wakumo.network**.

> **Note**
> The password is your Mac login password, not an SSL, GitHub, or wiki password. Terminal does not display characters while you type it.

Modern browsers may not display a green padlock. Successful installation means the connection is recognized as secure without certificate warnings.

## Manual Usage

If you have downloaded the script, make it executable:

```bash
chmod +x import-ssl.sh
```

### Install From a Local File

```bash
./import-ssl.sh --file ./wakumo-wiki-root-ca.crt
```

Or install the Plane/Headscale Root CA:

```bash
./import-ssl.sh --file ./wakumo-plan-root-ca.crt
```

You can supply any other trusted, valid self-signed Root CA in the same way. No fingerprint is hard-coded. To inspect and validate without installing, add `--check` before running the installation command.

### Install From an HTTPS URL

```bash
./import-ssl.sh --file 'https://github.com/wakumo/import-certificate/blob/main/wakumo-wiki-root-ca.crt'
```

Standard GitHub `/blob/` URLs are automatically converted to raw download URLs.

The URL must be accessible without authentication. Private GitHub repositories requiring authentication are not supported by this script. Download the certificate through an authenticated channel and use the local-file option instead.

### Validate Without Installing

Add `--check` to verify the certificate without changing your system trust settings:

```bash
./import-ssl.sh --file ./wakumo-wiki-root-ca.crt --check
```

You can also validate directly from GitHub without cloning:

```bash
(base=https://raw.githubusercontent.com/wakumo/import-certificate/main; bash <(curl -fsSL "$base/import-ssl.sh") --file "$base/wakumo-wiki-root-ca.crt" --check)
```

### Show Help

```bash
./import-ssl.sh --help
```

## Security

- The script requires a single self-signed Root CA with `CA:TRUE`, certificate-signing permission if Key Usage is present, a valid self-signature, and current validity dates. It rejects extra certificates, private keys, and extra non-whitespace data.
- The SHA-256 fingerprint is displayed for reference, not compared against an allowlist. Validation does **not** establish that the CA or its source is trustworthy. Confirm its source and fingerprint through a trusted channel before installation.
- HTTPS downloads use TLS verification. The download host must already be trusted by your Mac.
- The quick-install command executes the script from the current `main` branch. To use a fixed, reviewed version, replace `main` in the command with a full commit SHA.
- Installation adds the CA to the **macOS System Keychain** automatically after validation, with no `INSTALL` prompt. Administrator authorization is still required; the script does not bypass `sudo` password requirements.
- A Root CA can authenticate domains beyond the website you intend to access unless constrained by the certificate. Install it only if you trust whoever manages its private key.
- Only the public CA certificate should be distributed. **Never upload or share CA private keys, credentials, or Kubernetes Secrets.**
- Renewing the website certificate under the same CA does not require reinstalling the Root CA.

## Troubleshooting

| Issue | Action |
| --- | --- |
| `Permission denied` when running the script | Run `chmod +x import-ssl.sh`, or use `bash import-ssl.sh --file ./wakumo-wiki-root-ca.crt`. |
| Download fails | Check the URL, internet access, repository visibility, and the download host's TLS certificate. Do not assume installation succeeded if `curl` reports an error. |
| Password input appears blank | Terminal does not display password characters. Enter your Mac login password and press **Enter**. |
| Administrator permission is denied | Contact IT if your macOS account does not have administrator privileges. |
| Fingerprint mismatch | You are using the old, Wiki-only script. Use the updated script locally, or publish it to GitHub before using the online command. |
| Invalid input or CA validation fails | Supply exactly one public self-signed Root CA in PEM or DER, without private keys or extra data. Obtain a valid Root CA from your administrator; website and intermediate certificates are not supported. |
| Certificate expired or not yet valid | Check your Mac's date/time and obtain a currently valid Root CA from your administrator. |
| Browser still shows a certificate warning | Fully quit and reopen the browser, confirm the URL is `https://wiki.wakumo.network`, and check the exact browser error. |
| Firefox still reports an untrusted CA | Import the certificate under **Settings → Privacy & Security → Certificates → View Certificates → Authorities**, and allow it to identify websites. |
| Wiki cannot be reached | Check your Headscale connection, DNS resolution, and access permissions. Installing the CA does not configure network access. |
