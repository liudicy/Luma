#!/bin/sh
# Build QuickRecorder with a real signing identity and (optionally) prove that the
# Screen Recording grant survives a rebuild.
#
#   ./Scripts/build_and_check_signing.sh                 # probe + signed build + report
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

# A revoked certificate still passes codesign but gets its processes SIGKILLed by AMFI,
# and `security find-identity` lists revoked certificates first, so probe every identity
# and keep the first one whose binaries actually execute on this Mac.
# The id in the certificate's common name is NOT the team id. DEVELOPMENT_TEAM must
# equal the certificate's OU, which codesign reports as TeamIdentifier.
TEMPLATE=$(mktemp -d)
trap 'rm -rf "$TEMPLATE"' EXIT
printf 'int main(){return 0;}\n' > "$TEMPLATE/m.c"
xcrun clang -o "$TEMPLATE/m" "$TEMPLATE/m.c"

# Fingerprints, not names: names contain spaces and would word-split.
# `security find-identity` prints "  1) <SHA-1> "<name>"".
CANDIDATES=$(security find-identity -v -p codesigning \
	| awk '$1 ~ /^[0-9]+\)$/ && /Apple (Development|Distribution)/ {print $2}')
IDENT=""
TEAM=""
for candidate in $CANDIDATES; do
	# Every candidate needs a pristine file: AMFI caches the failed verdict on the vnode, so
	# re-signing a file that was already killed stays killed even with a good certificate.
	cp "$TEMPLATE/m" "$TEMPLATE/probe.$candidate"
	if codesign --force --sign "$candidate" "$TEMPLATE/probe.$candidate" 2>/dev/null \
		&& "$TEMPLATE/probe.$candidate" 2>/dev/null; then
		IDENT=$candidate
		TEAM=$(codesign -dvvv "$TEMPLATE/probe.$candidate" 2>&1 | sed -n 's/^TeamIdentifier=//p')
		break
	fi
	echo "skipping unusable certificate $candidate (revoked or expired: AMFI kills what it signs)" >&2
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
echo "certificate probe: binaries signed with it execute."
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
