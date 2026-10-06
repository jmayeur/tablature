# pr-follow-up

Nudge reviewers daily until the PR is approved, then merge.

Source: [pr-follow-up.tab](pr-follow-up.tab). Made with `bin/mermaidify --update`.

<!-- mermaidify: pr-follow-up.tab -->
```mermaid
flowchart TD
  START([start])
  START --> s_notify
  s_notify["notify · max 5<br/><small>use chat.post</small>"]
  s_notify --> s_wait
  s_wait{{"wait<br/><small>wait 24h</small>"}}
  s_wait --> s_check
  s_check["check<br/><small>use pr.status</small>"]
  s_check -- quiet --> s_notify
  s_check -- comments --> s_address
  s_check -- approved --> s_merge
  s_address("address<br/><small>use pr.comments</small>")
  s_address --> s_notify
  s_merge["🔒 merge<br/><small>run gh pr merge $inputs.pr --squash</small>"]
  s_merge --> END_
  END_([end])
  classDef agent fill:#ede7f6,stroke:#5e35b1,color:#1a1a1a
  classDef det fill:#e3f2fd,stroke:#1e88e5,color:#1a1a1a
  classDef human fill:#fff3e0,stroke:#fb8c00,color:#1a1a1a
  classDef wait fill:#eceff1,stroke:#546e7a,color:#1a1a1a
  classDef sub fill:#e8f5e9,stroke:#43a047,color:#1a1a1a
  class s_notify,s_check,s_merge det
  class s_wait wait
  class s_address agent
```
<!-- /mermaidify -->
