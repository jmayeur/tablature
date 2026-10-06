# Example flows

Each flow has a diagram in `<name>.mermaid.md`. To refresh them: `bin/mermaidify --update examples/*.mermaid.md`. For the colour key, see the [main README](../README.md#example).

| Flow | About | Diagram |
|---|---|---|
| [pr-follow-up.tab](pr-follow-up.tab) | Nudge reviewers daily until the PR is approved, then merge. | [diagram](pr-follow-up.mermaid.md) |
| [ticket-flow.tab](ticket-flow.tab) | Take one ticket from intake to merged PR, with review follow-up. | [diagram](ticket-flow.mermaid.md) |
| [hotfix.tab](hotfix.tab) | Ship a prod fix fast. Sample the demo box while the fix is built. | [diagram](hotfix.mermaid.md) |
| [demo-deploy.tab](demo-deploy.tab) | Build a ticket fix, measure it on the demo box, and open a PR with the results. | [diagram](demo-deploy.mermaid.md) |
| [fix.tab](fix.tab) | Make a worktree from main, fix the ticket red-green, and run the full test suite. | [diagram](fix.mermaid.md) |
