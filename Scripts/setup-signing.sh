#!/bin/bash
# One-time setup: creates a local self-signed code-signing certificate so the app
# has a STABLE identity across rebuilds. Without this, ad-hoc signing (`codesign -s -`)
# gets a new identity every build, so macOS Keychain treats every rebuild as a
# different app and keeps re-prompting for Keychain access.
set -euo pipefail

CERT_NAME="kantarto IPTV Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
  echo "Certificate '$CERT_NAME' already exists, nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -nodes \
  -subj "/CN=$CERT_NAME" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "keyUsage=digitalSignature" 2>/dev/null

PASS="tmp$(openssl rand -hex 8)"
openssl pkcs12 -export -out "$TMP/cert.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout "pass:$PASS"

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign -T /usr/bin/security
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo "Created and imported certificate: $CERT_NAME"
echo "You may see a one-time system prompt asking to allow 'codesign' to use this key — choose Always Allow."
