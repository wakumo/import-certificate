#!/bin/bash
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

# Public certificate only. Review the fingerprint through a trusted channel.
check_only=false
cert_file=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      if [ -n "$cert_file" ]; then
        printf 'Specify --file only once.\n' >&2
        exit 2
      fi
      if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ "$2" == --* ]]; then
        printf 'Option --file requires a certificate path or HTTPS URL.\n' >&2
        exit 2
      fi
      cert_file=$2
      shift 2
      ;;
    --check)
      check_only=true
      shift
      ;;
    --help)
      printf 'Usage: %s --file PATH_OR_HTTPS_URL [--check]\n' "$0"
      printf 'Accepts a local certificate or HTTPS URL (including standard GitHub blob URLs).\n'
      printf 'Install one public self-signed Root CA (PEM or DER) on macOS. --check validates without changing trust.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\nUse --help for usage.\n' "$1" >&2
      exit 2
      ;;
  esac
done
if [ -z "$cert_file" ]; then
  printf 'Required option: --file PATH_OR_HTTPS_URL\nUse --help for usage.\n' >&2
  exit 2
fi
case "$cert_file" in
  https://*) ;;
  *://*)
    printf 'Certificate URLs must use HTTPS; HTTP and other schemes are not supported.\n' >&2
    exit 2
    ;;
  *)
    if [ ! -f "$cert_file" ] || [ ! -r "$cert_file" ]; then
      printf 'Certificate must be a readable file.\n' >&2
      exit 1
    fi
    ;;
esac
if [ "$(uname -s)" != Darwin ]; then
  printf 'This installer supports macOS only.\n' >&2
  exit 1
fi

umask 077
temp_dir=$(mktemp -d /private/tmp/root-ca.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cert="$temp_dir/source.crt"
# Validate and import the same private snapshot of the supplied certificate.
case "$cert_file" in
  https://*)
    # Standard GitHub blob URLs use a single path segment for the ref.
    if [[ "$cert_file" =~ ^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$ ]]; then
      cert_file="https://raw.githubusercontent.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[3]}/${BASH_REMATCH[4]}"
    fi
    if ! /usr/bin/curl --disable --fail --silent --show-error --location \
      --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
      --max-redirs 5 --output "$cert" "$cert_file"; then
      printf 'Certificate download failed. Private GitHub files may return 404; use an accessible raw HTTPS URL or a local file.\n' >&2
      exit 1
    fi
    ;;
  *) cp -- "$cert_file" "$cert" ;;
esac

invalid_certificate() {
  printf 'Invalid input: supply exactly one public Root CA certificate in PEM or DER, without private keys or extra data.\n' >&2
  exit 1
}

# OpenSSL reads only the first certificate. Compare the full input against its
# re-encoding so bundles, private keys, and trailing data cannot be ignored.
if openssl x509 -inform PEM -in "$cert" -out "$temp_dir/root-ca.pem" 2>/dev/null; then
  LC_ALL=C tr -d '[:space:]' < "$cert" > "$temp_dir/input.compact"
  LC_ALL=C tr -d '[:space:]' < "$temp_dir/root-ca.pem" > "$temp_dir/output.compact"
  cmp -s "$temp_dir/input.compact" "$temp_dir/output.compact" || invalid_certificate
else
  openssl x509 -inform DER -in "$cert" -out "$temp_dir/root-ca.pem" 2>/dev/null || invalid_certificate
  openssl x509 -in "$temp_dir/root-ca.pem" -outform DER -out "$temp_dir/root-ca.der"
  cmp -s "$cert" "$temp_dir/root-ca.der" || invalid_certificate
fi
cert="$temp_dir/root-ca.pem"
details=$(openssl x509 -in "$cert" -noout -text)
constraints=$(printf '%s\n' "$details" | awk '/^[[:space:]]*X509v3 Basic Constraints:/ { getline; print }')
if ! printf '%s\n' "$constraints" | grep -Eq '(^|[[:space:],])CA:TRUE([[:space:],]|$)'; then
  printf 'Certificate must have CA:TRUE basic constraints.\n' >&2
  exit 1
fi
usage=$(printf '%s\n' "$details" | awk '/^[[:space:]]*X509v3 Key Usage:/ { getline; print }')
if [ -n "$usage" ] && ! printf '%s\n' "$usage" | grep -Eq '(^|[[:space:],])Certificate Sign([[:space:],]|$)'; then
  printf 'Certificate key usage must allow certificate signing.\n' >&2
  exit 1
fi
subject=$(openssl x509 -in "$cert" -noout -subject -nameopt RFC2253)
issuer=$(openssl x509 -in "$cert" -noout -issuer -nameopt RFC2253)
if [ "${subject#*=}" != "${issuer#*=}" ]; then
  printf 'Certificate must be a self-signed Root CA (subject must match issuer).\n' >&2
  exit 1
fi
openssl x509 -in "$cert" -checkend 0 -noout
# Explicitly check the trust anchor signature as well as its validity dates.
openssl verify -check_ss_sig -CAfile "$cert" "$cert"
openssl x509 -in "$cert" -noout -subject -dates -fingerprint -sha256
if [ "$check_only" = true ]; then
  printf 'Certificate checks passed. No trust settings changed.\n'
  exit 0
fi

printf '\nWarning: installing this Root CA into the macOS System Keychain allows it to authenticate any domain.\n'
printf 'Only install a CA you trust. sudo may request your password.\n'

# Reapplying the same certificate updates its trust without removing other CAs.
sudo /usr/bin/security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain "$cert"
/usr/bin/security verify-cert -c "$cert" -p basic
printf '\nRoot CA installed and verified. Fully quit and reopen your browser.\n'
