#!/usr/bin/env bash
# Get the review state of a PR.
# In:  TAB_PR (number or URL). Set GH_REPO to use a repo that is not the current one.
# Out: {verdict: quiet|comments|approved, open: <count of open threads>}
set -euo pipefail

# shellcheck disable=SC2016 # GraphQL variables, not shell.
query='query($o: String!, $n: String!, $p: Int!) {
  repository(owner: $o, name: $n) {
    pullRequest(number: $p) {
      reviewDecision
      reviewThreads(first: 100) { nodes { isResolved } }
    }
  }
}'

# The PR URL gives the owner, repo, and number.
url=$(gh pr view "$TAB_PR" --json url -q .url)
IFS=/ read -r _ _ _ owner name _ number <<<"$url"

gh api graphql -f query="$query" -f o="$owner" -f n="$name" -F p="$number" |
  jq '.data.repository.pullRequest
    | ([.reviewThreads.nodes[] | select(.isResolved | not)] | length) as $open
    | {open: $open,
       verdict: (if $open > 0 or .reviewDecision == "CHANGES_REQUESTED" then "comments"
                 elif .reviewDecision == "APPROVED" then "approved"
                 else "quiet" end)}' >"${TAB_OUT:-/dev/stdout}"
