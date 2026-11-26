#!/bin/sh
# One-time: create a self-signed code-signing identity "byaku dev" in the login keychain, so bundle.sh signs with a
# stable certificate and rebuilds keep the camera grant. Local dev only; releases stay ad-hoc until notarized.
# Afterwards, once: tccutil reset Camera dev.byaku.app (the old grant was for the ad-hoc signature).
set -eu
name="byaku dev"
if security find-identity -v -p codesigning | grep -q "\"$name\""; then echo "$name: already installed"; exit 0; fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
# /usr/bin/openssl is LibreSSL: Homebrew OpenSSL 3 writes a p12 that `security import` rejects (MAC error).
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$name" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
pass=$(/usr/bin/openssl rand -hex 16)  # throwaway: only protects the temp p12 on its way into the keychain
/usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$name" -passout "pass:$pass" -out "$tmp/id.p12"
security import "$tmp/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P "$pass" -T /usr/bin/codesign
echo "trusting $name for code signing (macOS asks for your password)"
security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$tmp/cert.pem"
security find-identity -v -p codesigning | grep "\"$name\""
