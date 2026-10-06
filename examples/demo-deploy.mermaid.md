# demo-deploy

Build a ticket fix, measure it on the demo box, and open a PR with the results.

Source: [demo-deploy.tab](demo-deploy.tab). Made with `bin/mermaidify --update`.

<!-- mermaidify: demo-deploy.tab -->
```mermaid
flowchart TD
  START([start])
  START --> s_ticket
  s_ticket["ticket<br/><small>use ticket.get</small>"]
  s_ticket --> s_fix
  s_fix[["fix<br/><small>tab fix.tab</small>"]]
  s_fix --> s_image
  s_image["image<br/><small>run docker build -t $vars.image:$ti…</small>"]
  s_image --> s_before
  s_before("before<br/><small>use demo.sample</small>")
  s_before --> s_deploy
  s_deploy["🔒 deploy<br/><small>run ssh $vars.host #quot;deploy $vars.im…</small>"]
  s_deploy --> s_after
  s_after("after<br/><small>use demo.sample</small>")
  s_after --> s_compare
  s_compare("compare<br/><small>do Compare the two samples. Report…</small>")
  s_compare -- worse --> s_decide
  s_compare --> s_pr
  s_decide{"decide<br/><small>ask The patch made things worse:</small>"}
  s_decide -- rollback --> s_rollback
  s_decide -- pr --> s_pr
  s_rollback[/"rollback<br/><small>revert deploy</small>"\]
  s_rollback --> END_
  s_pr["🔒 pr<br/><small>run git push -u origin HEAD</small>"]
  s_pr --> END_
  END_([end])
  classDef agent fill:#ede7f6,stroke:#5e35b1,color:#1a1a1a
  classDef det fill:#e3f2fd,stroke:#1e88e5,color:#1a1a1a
  classDef human fill:#fff3e0,stroke:#fb8c00,color:#1a1a1a
  classDef wait fill:#eceff1,stroke:#546e7a,color:#1a1a1a
  classDef sub fill:#e8f5e9,stroke:#43a047,color:#1a1a1a
  class s_ticket,s_image,s_deploy,s_rollback,s_pr det
  class s_fix sub
  class s_before,s_after,s_compare agent
  class s_decide human
```
<!-- /mermaidify -->
