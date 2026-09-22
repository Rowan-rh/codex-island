#!/bin/bash

PRODUCTION_SU_FEED_URL="https://github.com/ericjypark/codex-island/releases/latest/download/appcast.xml"

if [[ ${SU_FEED_URL+x} == x ]]; then
  RESOLVED_SU_FEED_URL="$SU_FEED_URL"
else
  RESOLVED_SU_FEED_URL="$PRODUCTION_SU_FEED_URL"
fi

if [[ -n "$RESOLVED_SU_FEED_URL" ]]; then
  SU_FEED_PLIST_ENTRY="  <key>SUFeedURL</key><string>$RESOLVED_SU_FEED_URL</string>"
else
  SU_FEED_PLIST_ENTRY=""
fi
