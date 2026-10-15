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

IDENT=$(security find-identity -v -p codesigning | awk -F'"' '/Apple (Development|Distribution)/{print $2; exit}')
if [ -z "$IDENT" ]; then
	cat >&2 <<EOF
No usable codesigning identity in the keychain.
Xcode > Settings > Accounts > <your Apple ID> > Manage Certificates > + > Apple Development
(a free Apple ID is enough for this; a paid program is only needed for Developer ID + notarization).
EOF
	exit 1
fi
echo "identity: $IDENT"

# A revoked certificate still passes codesign but gets its processes SIGKILLed by AMFI,
# so probe behaviour instead of trusting the certificate's stated validity dates.
PROBE=$(mktemp -d)
trap 'rm -rf "$PROBE"' EXIT
printf 'int main(){return 0;}\n' > "$PROBE/m.c"
xcrun clang -o "$PROBE/m" "$PROBE/m.c"
codesign --force --sign "$IDENT" "$PROBE/m" 2>/dev/null
if ! "$PROBE/m" 2>/dev/null; then
	echo "certificate is not usable on this Mac (AMFI kills binaries signed with it)." >&2
	echo "Apple revoked it: re-issue an Apple Development certificate in Xcode, then re-run." >&2
	exit 1
fi

# The id in the certificate's common name is NOT the team id. DEVELOPMENT_TEAM must
# equal the certificate's OU, which codesign reports as TeamIdentifier.
TEAM=$(codesign -dvvv "$PROBE/m" 2>&1 | sed -n 's/^TeamIdentifier=//p')
if [ -z "$TEAM" ] || [ "$TEAM" = "not set" ]; then
	echo "could not read a Team ID from a binary signed with $IDENT" >&2
	exit 1
fi
echo "certificate probe: binaries signed with it execute."
echo "team id (DEVELOPMENT_TEAM): $TEAM"

build() {
	xcodebuild -scheme QuickRecorder -configuration Release \
		-destination 'platform=macOS,arch=arm64' -derivedDataPath "$OUT" \
		DEVELOPMENT_TEAM="$TEAM" build
}

build
APP="$OUT/Build/Products/Release/QuickRecorder.app"
codesign --verify --strict --verbose=1 "$APP"
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
	pkill -x QuickRecorder 2>/dev/null || true
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
