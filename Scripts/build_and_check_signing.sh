#!/bin/sh
# Build QuickRecorder with a real signing identity and (optionally) prove that the
# Screen Recording grant survives a rebuild.
#
#   ./Scripts/build_and_check_signing.sh                 # certificate check + signed build + report
#   ./Scripts/build_and_check_signing.sh --reset-tcc     # also clear the stale grant
#   ./Scripts/build_and_check_signing.sh --prove         # full rebuild-survives-grant test
#
# Why this exists: without a Team ID, TCC can only bind kTCCServiceScreenCapture to
# the binary's cdhash, so every rebuild silently invalidates the grant and macOS
# re-prompts (tccd: "Failed to match existing code requirement"). A team-bound
# designated requirement is what makes the grant stick.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO"

DEV_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR=$DEV_DIR
BUNDLE_ID=com.liudicy.QuickRecorder
OUT="$REPO/build/signed-DerivedData"
RESET_TCC=0
PROVE=0
for arg in "$@"; do
	case "$arg" in
		--reset-tcc) RESET_TCC=1 ;;
		--prove) PROVE=1 ;;
		*) echo "unknown option: $arg" >&2; exit 2 ;;
	esac
done

# Validate certificates without signing or running a test executable. Executing a
# binary signed by a revoked identity triggers macOS's malware-blocked dialog.
# find-identity can still list revoked identities under -v, so reject annotated
# entries and independently verify the matching public certificate with OCSP.
CERT_WORK=$(mktemp -d)
trap 'rm -rf "$CERT_WORK"' EXIT
security find-certificate -a -p > "$CERT_WORK/all.pem"
awk -v folder="$CERT_WORK" '
    /-----BEGIN CERTIFICATE-----/ { count++; file = folder "/cert-" count ".pem" }
    file != "" { print > file }
    /-----END CERTIFICATE-----/ { close(file); file = "" }
' "$CERT_WORK/all.pem"

CANDIDATES=$(security find-identity -v -p codesigning \
    | awk '$1 ~ /^[0-9]+\)$/ && /Apple (Development|Distribution)/ && /"[[:space:]]*$/ {print $2}')
IDENT=""
TEAM=""
for candidate in $CANDIDATES; do
    for certificate in "$CERT_WORK"/cert-*.pem; do
        [ -f "$certificate" ] || continue
        fingerprint=$(/usr/bin/openssl x509 -in "$certificate" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')
        [ "$fingerprint" = "$candidate" ] || continue
        if security verify-cert -q -c "$certificate" -p codeSign -R ocsp -R require > "$CERT_WORK/verify.log" 2>&1; then
            IDENT=$candidate
            TEAM=$(/usr/bin/openssl x509 -in "$certificate" -noout -subject -nameopt sep_multiline \
                | sed -n 's/^[[:space:]]*OU[[:space:]]*=[[:space:]]*//p')
        else
            echo "skipping certificate that failed trust/revocation validation: $candidate" >&2
        fi
        break
    done
    [ -z "$IDENT" ] || break
done

if [ -z "$IDENT" ]; then
	cat >&2 <<EOF
No usable codesigning identity in the keychain.
Xcode > Settings > Accounts > <your Apple ID> > Manage Certificates > + > Apple Development
(a free Apple ID is enough for this; a paid program is only needed for Developer ID + notarization).
EOF
	exit 1
fi
if [ -z "$TEAM" ] || [ "$TEAM" = "not set" ]; then
	echo "could not read a Team ID from a binary signed with $IDENT" >&2
	exit 1
fi
echo "identity: $IDENT"
echo "certificate trust and OCSP revocation check: passed (no test executable)."
echo "team id (DEVELOPMENT_TEAM): $TEAM"

build() {
	xcodebuild -scheme QuickRecorder -configuration Release \
		-destination 'platform=macOS,arch=arm64' -derivedDataPath "$OUT" \
		DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_IDENTITY="$IDENT" CODE_SIGN_STYLE=Manual build
}

build
APP="$OUT/Build/Products/Release/Luma.app"
codesign --verify --strict --verbose=1 "$APP"
echo "Signed application: $APP"
echo "--- product identity ---"
codesign -dvvv "$APP" 2>&1 | grep -E '^(Identifier|CDHash|TeamIdentifier|Signature)='

cdhash_of() { codesign -dvvv "$APP" 2>&1 | sed -n 's/^CDHash=//p'; }

if [ "$RESET_TCC" = 1 ]; then
	echo "--- clearing the stale grant for $BUNDLE_ID ---"
	tccutil reset ScreenCapture "$BUNDLE_ID"
fi

if [ "$PROVE" = 1 ]; then
	echo
	echo "Launching the app. Grant Screen Recording in the system dialog, then come back here."
	open "$APP"
	printf "Press Enter once you have granted it... "
	read _
	OLD_HASH=$(cdhash_of)
	echo "rebuilding to change the cdhash ($OLD_HASH -> ...) ..."
	build
	NEW_HASH=$(cdhash_of)
	if [ "$OLD_HASH" = "$NEW_HASH" ]; then
		echo "warning: cdhash did not change, so this run proves nothing"
	fi
	pkill -x Luma 2>/dev/null || true
	open "$APP"
	printf "Press Enter once the app has been open for ~5 seconds... "
	read _
	if /usr/bin/log show --last 2m --style compact \
		--predicate 'process == "tccd" AND eventMessage CONTAINS "Failed to match existing code requirement"' \
		| grep -q "$BUNDLE_ID"; then
		echo "FAIL: TCC still cannot match the grant after a rebuild — the signature is still not team-bound."
		exit 1
	fi
	echo "PASS: rebuilt with a new cdhash, TCC matched the stored grant, no re-prompt."
fi
