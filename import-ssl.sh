#!/bin/bash
set -euo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

# Public certificate only. Review the fingerprint through a trusted channel.
expected='3E:0C:8C:41:D8:C0:17:84:59:96:97:FA:40:8B:D4:0D:4E:C6:00:FF:24:A8:75:0B:D9:49:AF:F0:E8:9F:EF:EF'
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
      printf 'Install the pinned wiki Root CA on macOS. --check validates without changing trust.\n'
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
temp_dir=$(mktemp -d /private/tmp/wakumo-wiki-ca.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cert="$temp_dir/root-ca.crt"
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

if ! actual=$(openssl x509 -in "$cert" -noout -fingerprint -sha256); then
  printf 'Invalid certificate (possibly an HTML sign-in page); use an accessible raw HTTPS URL or a local file.\n' >&2
  exit 1
fi
actual=${actual#*=}
if [ "$actual" != "$expected" ]; then
  printf 'Certificate fingerprint mismatch; refusing to install.\n' >&2
  exit 1
fi
openssl x509 -in "$cert" -checkend 0 -noout
openssl verify -CAfile "$cert" "$cert"
openssl x509 -in "$cert" -noout -subject -dates -fingerprint -sha256
if [ "$check_only" = true ]; then
  printf 'Certificate checks passed. No trust settings changed.\n'
  exit 0
fi

printf '\nThis installs a private Root CA into the macOS System Keychain.\n'
printf 'It can authenticate names beyond wiki.wakumo.network.\n'
printf 'Only proceed if you trust your company CA administrator and this script.\n'
printf 'Type INSTALL to continue: '
if ! IFS= read -r answer </dev/tty; then
  printf '\nAn interactive terminal is required.\n' >&2
  exit 1
fi
if [ "$answer" != INSTALL ]; then
  printf 'Cancelled. No trust settings changed.\n'
  exit 0
fi

# Reapplying the same certificate updates its trust without removing other CAs.
sudo /usr/bin/security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain "$cert"
/usr/bin/security verify-cert -c "$cert" -p basic
printf '\nRoot CA installed and verified. Fully quit and reopen your browser.\n'
printf 'Connect to Headscale and visit https://wiki.wakumo.network\n'
printf 'Firefox may require a separate CA import. This does not test website connectivity.\n'
