#!/bin/sh
# One-time Sparkle EdDSA setup for this fork.
#
# Generates the update-signing keypair OUTSIDE the repository, verifies that the
# pair can actually sign and validate, then writes the public half into
# QuickRecorder/Info.plist as SUPublicEDKey.
#
# The private key never lives in the repo and is never printed. Losing it means
# installs carrying the old public key can no longer validate your updates; leaking
# it means anyone can publish a signed update for your users.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
PLIST="$REPO/QuickRecorder/Info.plist"
KEY_DIR=${SPARKLE_KEY_DIR:-"$HOME/.sparkle-keys"}
KEY="$KEY_DIR/QuickRecorder-ed25519.pem"

command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }
[ -f "$PLIST" ] || { echo "Info.plist not found at $PLIST" >&2; exit 1; }

if [ -e "$KEY" ]; then
	echo "refusing to overwrite an existing key: $KEY" >&2
	echo "only delete it if you are certain this key was never shipped in a release." >&2
	exit 1
fi

umask 077
mkdir -p "$KEY_DIR"
openssl genpkey -algorithm ED25519 -out "$KEY"
chmod 600 "$KEY"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
echo "sparkle key self-test" > "$TEST_DIR/msg"

# The signature Sparkle puts in sparkle:edSignature is a plain RFC 8032 Ed25519
# signature over the archive bytes, so prove that shape end to end before touching
# the project file.
openssl pkeyutl -sign -inkey "$KEY" -rawin -in "$TEST_DIR/msg" -out "$TEST_DIR/msg.sig"
openssl pkey -in "$KEY" -pubout -out "$TEST_DIR/msg.pub"
openssl pkeyutl -verify -pubin -inkey "$TEST_DIR/msg.pub" -rawin -in "$TEST_DIR/msg" -sigfile "$TEST_DIR/msg.sig" >/dev/null
[ "$(openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | tail -c 32 | base64 | tr -d '\n' | wc -c | tr -d ' ')" = "44" ]
echo "ed25519 sign/verify self-test: OK"

PUB=$(openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | tail -c 32 | base64 | tr -d '\n')
OLD=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$PLIST" 2>/dev/null || echo "(unset)")
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $PUB" "$PLIST"

cat <<EOF

SUPublicEDKey written into QuickRecorder/Info.plist
  previous: $OLD
  new:      $PUB

private key: $KEY (mode 600, outside the repository)

Next: back the key file up somewhere private, then sign each release archive with
      ./Scripts/sign_update.sh <archive> and paste the printed
      sparkle:edSignature="..." into appcast.xml.
EOF
