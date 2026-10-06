# Tablature format, v0.1 (draft)

A `.tab` file is YAML. It says **what runs, in what order, and what each step returns**. It does not say *how* a step does its work. That belongs to skills, MCP tools, scripts, and recipes.

## File

| Key | Required | Meaning |
|---|---|---|
| `tab` | yes | Format version. `0.1` now. |
| `name` | yes | Flow id. Kebab case. Same as the file name. |
| `about` | yes | One line. What the flow does. |
| `actions` | no | Path to an actions file, or an inline map. See [Actions](#actions). |
| `inputs` | no | Values the caller gives. See [Inputs](#inputs). |
| `vars` | no | Values set once at start. Can refer to `$inputs`. Read as `$vars.<key>`. |
| `requires` | no | `tools`, `skills`, `mcp`, `env` the flow needs. The runner checks them before step one. |
| `rules` | no | Plain-English rules. The runner gives them to every agent step. Sub-tabs get them too. |
| `track` | no | Moves a ticket through statuses. See [Tracking](#tracking). |
| `out` | no | What this tab returns when another tab runs it. |
| `steps` | yes | Ordered map of step id → step. |

## Inputs

```yaml
inputs:
  ticket: {type: string, ask: optional}
  tracker: {type: choice, options: [jira, github], default: jira}
```

- `type`: `string`, `int`, `bool`, `duration`, `choice`, `list`.
- `ask`: `required` (prompt if missing), `optional` (may stay empty), `never` (caller must give it). Default: `never` when `default` is set, else `required`.

## Steps

Each step has **one kind key** and any number of common keys. Step ids are unique in the whole file, including ids inside `parallel` branches.

### Kinds

| Kind | Example | Does |
|---|---|---|
| `use` | `use: chat.post` | Runs a named action. See [Actions](#actions). |
| `do` | `do: Compare the samples.` | Agent task from one short prompt. |
| `skill` | `skill: github-pr-review` | Calls a Claude skill. |
| `mcp` | `mcp: atlassian/getJiraIssue` | Calls an MCP tool as `<server>/<tool>`. `with` gives the tool args. |
| `script` | `script: ./scripts/pr-status.sh` | Runs a file. See [Script contract](#script-contract). |
| `run` | `run: make test` | Runs inline shell. Same contract as `script`. |
| `ask` | `ask: Merge now?` | Asks the human. `options` makes the answer the verdict. |
| `wait` | `wait: 24h` | Durable pause. The run is saved and resumed later. |
| `parallel` | see below | Runs branches at the same time. |
| `revert` | `revert: deploy` | Runs the `undo` of an earlier step. |
| `tab` | `tab: ./fix.tab` | Runs a sub-flow. Its `out` becomes this step's outputs. |
| `recipe` | `recipe: ./triage.yaml` | Runs a goose recipe. `with` maps to recipe parameters. |

Use `use` in shared flows. Use the direct kinds (`skill`, `mcp`, `script`) in action files, or for one-off steps.

### Common keys

| Key | Meaning |
|---|---|
| `with` | Args for the step. |
| `out` | Output schema. A list value is a **verdict** enum: `out: {verdict: [ok, changes]}`. |
| `pick` | Map from output field to a path in the raw result: `pick: {title: fields.summary}`. |
| `as` | Store outputs under this name too. Two branches can fill the same name (`as: ticket`). |
| `if` | Run the step only if true. If false, the step is `skipped`. |
| `route` | Map of verdict or status → step id. (Not `on`: YAML 1.1 reads `on` as `true`.) |
| `next` | Step id to go to after this step (and after a skip). Default: the next step in the file. |
| `max` | Max visits to this step in one run. **Required on every step that a back-edge targets.** |
| `gate` | `confirm`: the human must approve before the step runs. |
| `effect` | `none`, `idempotent`, or `once` (default). See [Resume](#resume). |
| `guard` | Shell check. Exit 0 means "already done", so the step is `skipped`. |
| `undo` | Shell that reverses this step. A `revert` step runs it. |
| `in` | Working dir for the step. Usually a worktree. |
| `interactive` | The step talks to the human while it runs. |
| `timeout` | Duration. When it ends, the status is `inconclusive`. |

## Actions

An action is a named binding. A tab says *what* (`use: chat.post`). The actions file says *how*: a skill, an MCP tool, a script, or an agent prompt. Change the binding and every tab that uses it changes too.

```yaml
tab-actions: 0.1
actions:
  chat.post:   {script: ./scripts/gchat-post.sh, requires: {env: [GCHAT_BUILD_WEBHOOK]}}
  ticket.get:
    mcp: atlassian/getJiraIssue
    with: {cloudId: $env.JIRA_CLOUD_ID, issueIdOrKey: $with.id}
    pick: {id: key, title: fields.summary}
    out:  {id: string, title: string}
  pr.review:   {skill: github-pr-review, with: {pr: $with.pr}}
  ticket.move: {do: Move Jira issue $with.id to "$with.status".}
```

- An action has one kind key: `skill`, `mcp`, `script`, `run`, `do`, `tab`, or `recipe`.
- It can also set `with`, `pick`, `out`, `effect`, `interactive`, `timeout`, and `requires`. The step's own keys win over the action's.
- `$with.<key>` is the arg the step passed. If the action has no `with`, the step's `with` passes through as is.
- Paths in an action file are relative to that file.
- The tab's `requires` and each used action's `requires` are all checked before step one.

## Script contract

`script` and `run` steps use the same contract. It is the same idea as `$GITHUB_OUTPUT` in GitHub Actions.

- **In:** each `with` key is an env var `TAB_<KEY>` (upper case, `-` and `.` become `_`). Lists and objects are JSON.
- **Out:** the step writes a JSON object to the file at `$TAB_OUT`. If it writes nothing and `out` has one field, the last line of stdout fills that field.
- **Status:** exit 0 is `ok`. Non-zero is `fail`. A timeout is `inconclusive`.
- **Also set:** `TAB_RUN_ID`, `TAB_SCRATCH` (a temp dir for this run only).

## Parallel

```yaml
start:
  parallel:
    baseline:
      before: {use: demo.sample, with: {for: 20m}}
    fix:
      build: {tab: ./fix.tab, with: {ticket: $ticket.id}}
      image: {in: $build.worktree, run: docker build .}
  need: all
  timeout: 2h
```

- Each branch is an ordered map of steps. The steps in a branch run in order.
- `need`: `all` (default), `any`, or a number. When `need` is met, the runner stops the other branches. Their status is `skipped`.
- The `parallel` step is `ok` when `need` is met. Otherwise it is `fail`. A timeout makes it `inconclusive`.
- A branch step can only route (`route`, `next`) inside its own branch, or to `end` or `fail`.
- After the join, later steps can read the outputs of every branch step.
- Two branches must not change the same files. Only the runner commits.

## Status and routing

Every step ends with one **status**: `ok`, `fail`, `inconclusive`, or `skipped`. A step with a verdict in `out` also has a **verdict**.

The runner picks the next step in this order:

1. `route[verdict]`, if it is set.
2. `route[status]`, if it is set.
3. If the status is `fail` or `inconclusive`: stop the run as failed. `inconclusive` is never treated as `ok`.
4. `next`, if it is set.
5. The next step in the file. After the last step, the run ends.

Reserved targets: `end` (stop, success) and `fail` (stop, failure).

A back-edge (a jump to an earlier step) makes a loop. The target must set `max`. When `max` is used up, the step's status is `fail`.

## Expressions

- References: `$inputs.x`, `$vars.x`, `$env.X`, `$<step-or-as>.<field>`, `$user`, `$run.id`. In action files, also `$with.x`. Use `${...}` when text follows directly.
- In `if`: `==`, `!=`, `and`, `or`, `not`, `in`, `empty(x)`, `a ?? b` (first value that is not empty).
- No loops or templates inside strings. Keep logic in the step graph.
- The validator checks each reference against the `out` of the step that makes it.

YAML traps. Quote these, or use a block (`run: |`):

- Values that contain `: ` (shell commands, titles).
- Expressions with `??` inside `{...}`. Some parsers read `?` as a key marker.
- Verdicts and options named `yes`, `no`, `on`, `off`. YAML 1.1 reads them as booleans. Prefer words like `approve` and `hold`.

## Tracking

```yaml
track:
  ticket: $ticket.id
  via: ticket.move
  status: {fix: In Progress, pr: In Review, merge: Done}
```

When a listed step starts, the runner calls the `via` action with `{id, status}`. A tracking failure is logged, but it does not stop the run.

## Resume

Each run has a folder: `.tablature/runs/<run-id>/`.

- `state.json`: current step, outputs, visit counts, status of each step.
- `timeline.jsonl`: one line per event. Append only.
- `scratch/`: temp files for this run only.

On resume, the runner does this for each step it reaches again:

| `effect` | On resume |
|---|---|
| `none` | Runs again. It reads state only. |
| `idempotent` | Runs again. A second run is safe. |
| `once` | Does not run again if `state.json` says `ok`. If `guard` is set, the runner checks it first. |

`wait` saves state, books a wake-up (Claude Code `/schedule`, cron, or `goose schedule`), and ends the session. The wake-up runs the flow again with `resume <run-id>`.
