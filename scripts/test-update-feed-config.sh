#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

default_output=$(env -u SU_FEED_URL bash -eu -c 'source scripts/update-feed-config.sh; printf "%s\n%s" "$RESOLVED_SU_FEED_URL" "$SU_FEED_PLIST_ENTRY"')
[[ "$default_output" == *"https://github.com/ericjypark/codex-island/releases/latest/download/appcast.xml"* ]]
[[ "$default_output" == *"<key>SUFeedURL</key>"* ]]

empty_output=$(SU_FEED_URL= bash -eu -c 'source scripts/update-feed-config.sh; printf "%s" "$SU_FEED_PLIST_ENTRY"')
[[ -z "$empty_output" ]]

custom_output=$(SU_FEED_URL=https://example.com/custom.xml bash -eu -c 'source scripts/update-feed-config.sh; printf "%s\n%s" "$RESOLVED_SU_FEED_URL" "$SU_FEED_PLIST_ENTRY"')
[[ "$custom_output" == *"https://example.com/custom.xml"* ]]
[[ "$custom_output" == *"<key>SUFeedURL</key>"* ]]

grep -q 'SU_PUBLIC_KEY="bz1gwLBKgIL/Y7OO23o3gaMNIeTpvv/C90F9inr9Quo="' build.sh
grep -q 'BUNDLE_ID="dev.codexisland.CodexIsland"' build.sh

echo "PASS update feed configuration"
