#!/usr/bin/env bash
# Add as reviewers the users who changed the PR's files in a recent time window.
# In:  TAB_PR (number), TAB_SINCE (for example 30d). TAB_DRY_RUN=1 does not edit the PR.
# Out: {added: [logins]}
set -euo pipefail

days="${TAB_SINCE:-30d}"
days="${days%d}"
since=$(date -u -v-"${days}"d +%FT%TZ 2>/dev/null || date -u -d "$days days ago" +%FT%TZ)

me=$(gh api user -q .login)
author=$(gh pr view "$TAB_PR" --json author -q .author.login)

logins=$(
  gh pr view "$TAB_PR" --json files -q '.files[].path' |
    while IFS= read -r file; do
      gh api -X GET 'repos/{owner}/{repo}/commits' -f path="$file" -f since="$since" \
        --paginate -q '.[].author.login // empty'
    done |
    sort -u | grep -vxF -e "$me" -e "$author" | grep -v -e '\[bot\]$' -e '^web-flow$' || true
)

if [[ -n "$logins" && "${TAB_DRY_RUN:-0}" != 1 ]]; then
  gh pr edit "$TAB_PR" --add-reviewer "$(paste -sd, - <<<"$logins")" >/dev/null
fi

jq -n --arg l "$logins" '{added: ($l | split("\n") | map(select(. != "")))}' >"${TAB_OUT:-/dev/stdout}"
