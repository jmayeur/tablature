# fix

Make a worktree from main, fix the ticket red-green, and run the full test suite.

Source: [fix.tab](fix.tab). Made with `bin/mermaidify --update`.

<!-- mermaidify: fix.tab -->
```mermaid
flowchart TD
  START([start])
  START --> s_worktree
  s_worktree["worktree<br/><small>run git fetch origin main && git wo…</small>"]
  s_worktree --> s_build
  s_build("build · max 3<br/><small>do Fix $inputs.ticket red-green. S…</small>")
  s_build --> s_test
  s_test["test<br/><small>run $inputs.test</small>"]
  s_test -. fail .-> s_build
  s_test -. inconclusive .-> s_build
  s_test --> END_
  END_([end])
  classDef agent fill:#ede7f6,stroke:#5e35b1,color:#1a1a1a
  classDef det fill:#e3f2fd,stroke:#1e88e5,color:#1a1a1a
  classDef human fill:#fff3e0,stroke:#fb8c00,color:#1a1a1a
  classDef wait fill:#eceff1,stroke:#546e7a,color:#1a1a1a
  classDef sub fill:#e8f5e9,stroke:#43a047,color:#1a1a1a
  class s_worktree,s_test det
  class s_build agent
```
<!-- /mermaidify -->
