#!/usr/bin/env bash
# Post a message to a Google Chat space through an incoming webhook.
# In:  TAB_CHANNEL, TAB_TEXT. The webhook URL is in GCHAT_<CHANNEL>_WEBHOOK.
# Out: none.
set -euo pipefail

var="GCHAT_$(tr '[:lower:]-' '[:upper:]_' <<<"$TAB_CHANNEL")_WEBHOOK"
url="${!var:?set $var}"

jq -n --arg text "$TAB_TEXT" '{text: $text}' |
  curl -fsS -X POST -H 'Content-Type: application/json; charset=UTF-8' --data @- "$url" >/dev/null
