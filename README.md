macOS Wiki SSL Certificate Installer
import-ssl.sh installs and trusts the Wakumo Wiki Root CA on macOS, allowing developers and testers to access https://wiki.wakumo.network without certificate trust warnings.

Requirements
macOS with administrator privileges.
A connection to the company Headscale network to access the wiki.
Internet access to download the installer and certificate from GitHub.
Quick Install
Run this single command in Terminal. No cloning or manual downloads are required:

(base=https://raw.githubusercontent.com/wakumo/import-certificate/main; bash <(curl -fsSL "$base/import-ssl.sh") --file "$base/wakumo-wiki-root-ca.crt")
The command downloads and runs the installer directly from this repository. Only run it if you trust the repository owner and its contents.

Review the certificate information.
Type INSTALL to confirm.
Enter your Mac login password when prompted by sudo. This is not an SSL, GitHub, or wiki password. Password characters are not displayed while typing.
Fully quit your browser using Cmd + Q, then reopen it.
Connect to Headscale and visit https://wiki.wakumo.network.
Modern browsers may not display a green padlock. Successful installation means the connection is recognized as secure without certificate warnings.

Manual Usage
If you have downloaded the script, make it executable:

chmod +x import-ssl.sh
Install From a Local File
./import-ssl.sh --file ./wakumo-wiki-root-ca.crt
Install From an HTTPS URL
./import-ssl.sh --file 'https://github.com/wakumo/import-certificate/blob/main/wakumo-wiki-root-ca.crt'
Standard GitHub /blob/ URLs are automatically converted to raw download URLs.

The URL must be accessible without authentication. Private GitHub repositories requiring authentication are not supported by this script; download the certificate through an authenticated channel and use the local-file option instead.

Validate Without Installing
Add --check to verify the certificate without changing your system trust settings:

./import-ssl.sh --file ./wakumo-wiki-root-ca.crt --check
You can also validate directly from GitHub without cloning:

(base=https://raw.githubusercontent.com/wakumo/import-certificate/main; bash <(curl -fsSL "$base/import-ssl.sh") --file "$base/wakumo-wiki-root-ca.crt" --check)
Show Help
./import-ssl.sh --help
Security
The script verifies the certificate against the expected Wakumo Wiki Root CA fingerprint and checks its validity before installation.
HTTPS downloads use TLS verification. The download host must already be trusted by your Mac.
The quick-install command executes the script from the current main branch. To use a fixed, reviewed version, replace main in the command with a full commit SHA.
Installation adds the CA to the macOS System Keychain and requires explicit confirmation and administrator authorization.
This CA is not technically restricted to the wiki hostname. Install it only if you trust the company managing its private key.
Only the public CA certificate should be distributed. Never upload or share CA private keys, credentials, or Kubernetes Secrets.
Renewing the website certificate under the same CA does not require reinstalling the Root CA.
Troubleshooting
Issue	Action
Permission denied when running the script	Run chmod +x import-ssl.sh, or use bash import-ssl.sh --file ./wakumo-wiki-root-ca.crt.
Download fails	Check the URL, internet access, repository visibility, and the download host’s TLS certificate. Do not assume installation succeeded if curl reports an error.
Password input appears blank	Terminal does not display password characters. Enter your Mac login password and press Enter.
Administrator permission is denied	Contact IT if your macOS account does not have administrator privileges.
Fingerprint mismatch	Stop and obtain the correct certificate from your administrator. Do not bypass verification.
Browser still shows a certificate warning	Fully quit and reopen the browser, confirm the URL is https://wiki.wakumo.network, and check the exact browser error.
Firefox still reports an untrusted CA	Import the certificate under Settings → Privacy & Security → Certificates → View Certificates → Authorities, and allow it to identify websites.
Wiki cannot be reached	Check your Headscale connection, DNS resolution, and access permissions. Installing the CA does not configure network access.