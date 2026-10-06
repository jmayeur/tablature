# ticket-flow

Take one ticket from intake to merged PR, with review follow-up.

Source: [ticket-flow.tab](ticket-flow.tab). Made with `bin/mermaidify --update`.

<!-- mermaidify: ticket-flow.tab -->
```mermaid
flowchart TD
  START([start])
  START --> s_intake
  s_intake{"intake<br/><small>ask No ticket given. Enter an id, o…</small>"}
  s_intake -- enter --> s_enter
  s_intake -- create --> s_title
  s_intake -. skip .-> s_find
  s_enter{"enter<br/><small>ask Ticket id?</small>"}
  s_enter --> s_find
  s_title{"title<br/><small>ask Title for the new ticket?</small>"}
  s_title --> s_create
  s_create["create<br/><small>use ticket.create</small>"]
  s_create --> s_claim
  s_find["find<br/><small>use ticket.get</small>"]
  s_find --> s_claim
  s_claim["claim<br/><small>use ticket.claim</small>"]
  s_claim --> s_fix
  s_fix[["fix<br/><small>tab fix.tab</small>"]]
  s_fix --> s_pr
  s_pr["🔒 pr<br/><small>run git push -u origin HEAD</small>"]
  s_pr --> s_self_review
  s_self_review("self-review<br/><small>use pr.review</small>")
  s_self_review --> s_self_comments
  s_self_comments("self-comments<br/><small>use pr.comments</small>")
  s_self_comments --> s_reviewers
  s_reviewers["reviewers<br/><small>use pr.reviewers</small>"]
  s_reviewers --> s_notify
  s_notify["notify · max 5<br/><small>use chat.post</small>"]
  s_notify --> s_wait
  s_wait{{"wait<br/><small>wait 24h</small>"}}
  s_wait --> s_check
  s_check["check<br/><small>use pr.status</small>"]
  s_check -- quiet --> s_notify
  s_check -- comments --> s_address
  s_check -- approved --> s_merge
  s_address("address<br/><small>use pr.comments</small>")
  s_address -- approved --> s_merge
  s_address -- pending --> s_notify
  s_merge["🔒 merge<br/><small>run gh pr merge $pr.number --squash…</small>"]
  s_merge --> END_
  END_([end])
  classDef agent fill:#ede7f6,stroke:#5e35b1,color:#1a1a1a
  classDef det fill:#e3f2fd,stroke:#1e88e5,color:#1a1a1a
  classDef human fill:#fff3e0,stroke:#fb8c00,color:#1a1a1a
  classDef wait fill:#eceff1,stroke:#546e7a,color:#1a1a1a
  classDef sub fill:#e8f5e9,stroke:#43a047,color:#1a1a1a
  class s_intake,s_enter,s_title human
  class s_create,s_find,s_claim,s_pr,s_reviewers,s_notify,s_check,s_merge det
  class s_fix sub
  class s_self_review,s_self_comments,s_address agent
  class s_wait wait
```
<!-- /mermaidify -->
