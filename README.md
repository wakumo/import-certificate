macOS Wiki SSL Certificate Installer
import-ssl.sh installs and trusts the Wakumo Wiki Root CA on macOS, allowing developers and testers to access https://wiki.wakumo.network without certificate trust warnings.

Requirements
macOS with administrator privileges.
A connection to the company Headscale network to access the wiki.
The official Wakumo Wiki Root CA certificate, available locally or through an accessible HTTPS URL.
Usage
Make the script executable:

chmod +x import-ssl.sh
Install From a Local File
./import-ssl.sh --file /path/wakumo.crt
Install From an HTTPS URL
./import-ssl.sh --file 'https://github.com/wakumo/wakumo-development-k8s/blob/main/ssl.crt'
Standard GitHub /blob/ URLs are automatically converted to raw download URLs. Replace the example URL with the actual certificate location.

The URL must be accessible without authentication. Private GitHub repositories requiring authentication are not supported by this script; download the certificate through an authenticated channel and use the local-file option instead.

Validate Without Installing
Add --check to verify the certificate without changing your system trust settings:

./import-ssl.sh --file /path/wakumo.crt --check
Show Help
./import-ssl.sh --help
Installation Steps
Run the script using one of the commands above.
Review the certificate information.
Type INSTALL to confirm.
Enter your macOS password when prompted by sudo. Password characters are not displayed.
Fully quit your browser using Cmd + Q, then reopen it.
Connect to Headscale and visit https://wiki.wakumo.network.
Modern browsers may not display a green padlock. Successful installation means the connection is recognized as secure without certificate warnings.

Security
The script verifies the certificate against the expected Wakumo Wiki Root CA fingerprint and checks its validity before installation.
HTTPS downloads use TLS verification. The download host must already be trusted by your Mac.
Installation adds the CA to the macOS System Keychain and requires explicit confirmation and administrator authorization.
This CA is not technically restricted to the wiki hostname. Install it only if you trust the company managing its private key.
Only the public CA certificate should be distributed. Never upload or share CA private keys, credentials, or Kubernetes Secrets.
Renewing the website certificate under the same CA does not require reinstalling the Root CA.
Troubleshooting
Issue	Action
Permission denied when running the script	Run chmod +x import-ssl.sh, or use bash import-ssl.sh --file /path/wakumo.crt.
Download fails	Check the URL, network access, repository visibility, and the download host’s TLS certificate.
Fingerprint mismatch	Stop and obtain the correct certificate from your administrator. Do not bypass verification.
Browser still shows a certificate warning	Fully quit and reopen the browser, confirm the URL is https://wiki.wakumo.network, and check the exact browser error.
Firefox still reports an untrusted CA	Import the certificate under Settings → Privacy & Security → Certificates → View Certificates → Authorities, and allow it to identify websites.
Wiki cannot be reached	Check your Headscale connection, DNS resolution, and access permissions. Installing the CA does not configure network access.