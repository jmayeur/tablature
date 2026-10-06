# Design notes

## The problem

Skills mix four things: intent, how-to, examples, and flow. The flow part ("do A, then B, ask before C, retry D, check again in 24h") gets lost in the prose. An agent can skip it, re-order it, or forget it after context compaction.

Tablature pulls the flow out into a short file that a person can review in one screen and a validator can check.

## Principles

1. **Flow only.** A `.tab` file says what runs, in what order, and what it returns. Skills, recipes, and scripts say how.
2. **One screen.** If a tab is long, move work into a skill or a sub-tab.
3. **State machine first.** Agent work loops (review → fix → review). Steps run in file order, with `route`/`next` jumps. Every loop has a `max`.
4. **Explicit gates.** Outward-facing steps (open PR, merge, post) say `gate: confirm`.
5. **Safe resume.** Every step declares what happens if it runs twice (`effect`). A posted review cannot be un-posted.
6. **Inconclusive is not ok.** A timeout or a crashed check stops the run unless the tab routes it.
7. **Check before run.** `requires` is checked before step one. A missing tool fails fast, not in step nine.
8. **Durable waits.** `wait: 24h` saves state and ends the session. It does not hold a process open.
9. **Bind actions, do not hard-code them.** A tab says `use: chat.post`. An actions file says if that is a script, a skill, an MCP tool, or an agent prompt. A team can move Jira from a skill to MCP, or Chat from a skill to a webhook script, and not change one tab.

## Action types

| Kind | Good for | Example |
|---|---|---|
| `script` / `run` | Fixed, testable work. No model needed. | `gchat-post.sh`, `pr-status.sh` |
| `mcp` | A service that has an MCP server. | Jira through `atlassian/getJiraIssue` |
| `skill` | Work that needs judgment and a long how-to. | `github-pr-review` |
| `do` | Small judgment work, or glue around an awkward API. | Jira transition by status name |
| `tab` | A shared part of many flows. | `fix.tab` in `ticket-flow` and `hotfix` |
| `recipe` | Work that is already a goose recipe. | |

Prefer the lowest row that works, from the top: a script is cheaper and more predictable than an agent.

## Where these came from

From running agent flows in practice:

| Lesson | Source | Becomes |
|---|---|---|
| A posted PR review cannot be deleted. Re-runs must check first. | PR review skill | `effect: once`, `guard` |
| A PR comment handler can be built to re-run safely. | PR comments skill | `effect: idempotent` |
| Ask before you open a PR, merge, or post. | team rules | `gate: confirm` |
| "No checks" means never, not pending. A crashed test is not green. | team rules | `inconclusive` status |
| Poll → stage → apply → bake → revert, with a status file. | image update flows | `undo`, `state.json` |
| A ledger of rejected review findings makes the loop converge. | self-review practice | Open: per-run ledger (see below) |
| A documented tool was not installed. | team notes | `requires` |
| Shared `/tmp` paths collide across runs. | PR skills | per-run `scratch/` |
| One worktree per ticket. | worktree conventions | `in:` |

From other tools:

| Tool | Borrowed |
|---|---|
| Microsoft Conductor | Closest match. See [below](#closest-prior-art-microsoft-conductor). |
| AWS Step Functions | Verdict routing (`Choice`), `Wait`, explicit end states |
| Archon | Typed outputs checked at validate time; `interactive` steps; worktree per run |
| Goose recipes | `ask` levels on inputs; shell checks as an oracle |
| GitHub Actions | `if`, `with`, `outputs`, environment approvals as gates |
| Temporal | A long wait is saved state plus an outside wake-up |
| Taskfile | `guard` (Taskfile's `status:`): skip work that is already done |

## Closest prior art: Microsoft Conductor

[Conductor](https://github.com/microsoft/conductor) ([announcement](https://opensource.microsoft.com/blog/2026/05/14/conductor-deterministic-orchestration-for-multi-agent-ai-workflows/), MIT, May 2026) is the nearest tool to tablature. It is a CLI that runs YAML flows of agents with a deterministic engine.

**What it has that tablature also has:** routes between steps (Jinja2 conditions, first match wins), loops with iteration caps and timeouts, parallel groups, script steps, human gates, MCP tools, reusable sub-workflows, `conductor validate`, and a flow graph in a web dashboard. It runs Claude and Copilot models.

**What tablature adds (as of this draft):**

| Need | Conductor | Tablature |
|---|---|---|
| Step runs an existing agent skill (for example `github-pr-review`) | A step is a model + prompt that Conductor calls | `skill:` runs in the user's agent harness, with its skills, MCP logins, and worktrees |
| Swap an integration for the whole team | Edit each workflow | `use:` + a shared `actions.yaml` |
| Wait 24h, then continue | Wait step + polling loop; no documented resume | `wait:` saves state, books a wake-up, ends the session |
| Safe re-run after a crash | Not documented | `effect: none / idempotent / once`, `guard` |
| Ticket status follows the flow | No | `track:` |

**What Conductor does better:** its routing is deterministic code. The tablature v0.1 runner is an agent that follows `SKILL.md`, so it can drift. To keep flows consistent, the tablature runner core (state, routing, `max`, waits) should become a small deterministic program. The agent then does only the agentic steps.

**Plan:** port `ticket-flow.tab` to Conductor YAML and list the gaps. If the gaps are only waits, resume, actions, and skills, tablature can compile to Conductor, or add those features upstream. If Conductor cannot drive agent-harness sessions well, keep tablature and build the deterministic runner next.

## Goose and goosetown

[goosetown](https://github.com/aaif-goose/goosetown) runs multi-agent work from a prose orchestrator skill: phases, delegate counts, "crossfire" review by two models, and wrap-up timeouts. It has no flow file. [Goose recipes](https://goose-docs.ai/docs/guides/recipes/recipe-reference) are single tasks. Their `sub_recipes` are tools that the model may call, so the order is not fixed. They have no branches, no one-shot waits, and no resume.

Tablature fits beside them:

- **Recipes as steps.** `recipe: path.yaml` with `with:` runs a recipe. Its `response.json_schema` can serve as the step's `out`.
- **goosetown as a tab.** The orchestrator's phases become steps. Delegate role skills become `skill:` steps. Crossfire becomes a parallel review that needs two approvals. The runner can post step changes to the town wall for the dashboard.
- **Export, not runtime.** A simple tab could compile to a parent recipe, but the recipe would lose fixed order and durable waits.

## Open questions

1. **Parallel conflicts.** `parallel` branches must not change the same files. Should the validator check `in` dirs, or should each branch get its own worktree?
2. **Review ledger.** Should the runner keep rejected findings per run, and pass them to every review step?
3. **Runner.** v0.1 is a Claude Code skill (`skills/tablature`). Next: a small deterministic CLI that owns state, routing, and waits, and asks the agent to do only the agentic steps. Or compile to Conductor (see above).
4. **Wake-up backend.** Claude Code `/schedule`, cron, or `goose schedule`. Pick one default.
5. **Action discovery.** Today a tab names its actions file. Should there also be a user-level default (`~/.tablature/actions.yaml`) that a repo file can override?
6. **Merge policy.** `ticket-flow` gates merge with `confirm`. Should an approved PR with no comments merge without asking?
7. **Schema.** Write `schema/tab.schema.json` and a `tab validate` command, after the syntax settles.
