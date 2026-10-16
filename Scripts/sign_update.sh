#!/bin/sh
# Produce the Sparkle EdDSA signature for a release archive.
#
#   ./Scripts/sign_update.sh <archive.dmg|zip> [private-key.pem]
#
# Prints the exact appcast attribute plus the byte size the enclosure also needs.
# Sign the file you will actually upload: the signature covers these bytes, so a
# rebuild that changes the archive invalidates it.
set -eu

ARCHIVE=${1:?usage: sign_update.sh <archive> [private-key]}
KEY=${2:-${SPARKLE_PRIVATE_KEY_FILE:-"$HOME/.sparkle-keys/QuickRecorder-ed25519.pem"}}

[ -f "$ARCHIVE" ] || { echo "no such archive: $ARCHIVE" >&2; exit 1; }
[ -f "$KEY" ] || { echo "private key not found: $KEY" >&2; echo "run ./Scripts/generate_sparkle_keys.sh first" >&2; exit 1; }

SIG=$(openssl pkeyutl -sign -inkey "$KEY" -rawin -in "$ARCHIVE" | base64 | tr -d '\n')
SIZE=$(wc -c < "$ARCHIVE" | tr -d ' ')

printf 'sparkle:edSignature="%s"\n' "$SIG"
printf 'length="%s"\n' "$SIZE"
