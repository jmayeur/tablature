---
name: tablature
description: Run, resume, check, or validate a tablature flow (.tab file). Use when the user says "run <name>.tab", "/tablature", "resume run <id>", or asks for the status of a tab run.
argument-hint: "run <file.tab> [key=value ...] | resume <run-id> | status [run-id] | validate <file.tab>"
---

# Tablature runner

A `.tab` file is the flow. Follow it exactly. Do not add, skip, or re-order steps. The format spec is `docs/spec.md` in the tablature repo. Read it if a key is not clear.

## Commands

| Command | Do |
|---|---|
| `run <file> [k=v ...]` | Validate, then start a new run. |
| `resume <run-id>` | Load the state and continue from the saved step. |
| `status [run-id]` | Show the current step, the visit counts, and the last 10 timeline events. No id: list the runs. |
| `validate <file>` | Do the checks in step 1 only. Report each problem with its step id. |

## 1. Validate

Load the tab, its actions file, and every sub-tab. Stop on the first problem.

- Each step has exactly one kind key.
- Each `use` names an action that exists.
- Each `route` and `next` target is a step id, `end`, or `fail`. Each `revert` names a step that has `undo`.
- Each back-edge target has `max`.
- Each `$step.field` reference matches an `out` field (or `as`) of a step that can run before it.
- Each verdict key in `route` is in that step's verdict list.
- Branch steps route only inside their branch, or to `end` or `fail`.

## 2. Preflight

- Check `requires` for the tab and for each action it uses:
  - tools: `command -v`
  - skills: the skill is in your skill list
  - MCP tools: load with ToolSearch `select:mcp__<server>__<tool>`
  - env: the variable is set
- Report every missing item together, then stop. Do not start a run with missing items.
- Fill `inputs`. Ask for each `required` input that is missing. Use AskUserQuestion for `choice` inputs.

## 3. Start the run

- Run id: `<name>-<yyyymmdd-hhmm>`.
- Make `.tablature/runs/<run-id>/` in the repo root, with `state.json`, `timeline.jsonl`, and `scratch/`.
- `state.json` holds: `tab` (path), `inputs`, `vars`, `current`, `steps` (`{status, verdict, out, visits}` for each id), and `wake` (for a wait).
- Before you do a step, write a line to `timeline.jsonl`: `{"t": <iso>, "step": <id>, "event": "start"}`. After the step, write an `end` line with the status and verdict. Update `state.json` after each step. Never edit old timeline lines.

## 4. Do each step

In this order:

1. **Visits.** Add 1 to the visit count. If it is more than `max`, the status is `fail`.
2. **`if`.** If it is false, the status is `skipped`. Go to routing.
3. **`guard`.** If it exits 0, the status is `skipped`.
4. **Resume.** If `effect` is `once` (the default) and the saved status is `ok`, use the saved outputs. Do not run the step again.
5. **`track`.** If this step id is in `track.status`, call the `via` action. If it fails, log it and continue.
6. **`gate: confirm`.** Show what the step will do, with all references filled in. Ask yes or no with AskUserQuestion. If the answer is no, stop the run. The status is `fail`, and `state.json` stays, so the run can be resumed.
7. **Dispatch** by kind. Set the working dir to `in` if it is given.

| Kind | How |
|---|---|
| `use` | Look up the action. Merge the action's keys under the step's keys. Fill `$with.*` from the step's `with`. Then dispatch the action's kind. |
| `do` | Do the task yourself. Give it the tab's `rules`. Return the `out` fields as JSON. |
| `skill` | Call the Skill tool. Pass `with` as `key=value` args. Give it the tab's `rules`. Get the `out` fields from the result. |
| `mcp` | Call `mcp__<server>__<tool>` with `with` as the args. Apply `pick` to the result. |
| `script`, `run` | Run in Bash. Set the `TAB_*` env, `TAB_OUT=<scratch>/<id>.json`, `TAB_RUN_ID`, `TAB_SCRATCH`. Read `TAB_OUT` after the step. Exit 0 is `ok`. |
| `ask` | AskUserQuestion. With `options`, the answer is the verdict. Without them, the answer goes in `out.answer`. |
| `wait` | See [Waits](#5-waits). |
| `parallel` | See [Parallel](#6-parallel). |
| `revert` | Run the `undo` command of the named step, in that step's `in` dir. If that step did not run, the status is `skipped`. |
| `tab` | Run the sub-tab in this run. Prefix its step ids with `<step-id>/`. Its `out` becomes this step's outputs. |
| `recipe` | Run `goose run --recipe <path> --params k=v ...`. |

8. **Check outputs.** Each declared `out` field must be present. A verdict must be in its list. If not, the status is `inconclusive`.
9. **Timeout.** If `timeout` ends, the status is `inconclusive`.

Then route:

1. `route[verdict]`
2. `route[status]`
3. `fail` or `inconclusive`: stop the run as failed
4. `next`
5. The next step in the file

`end` stops with success. `fail` stops with failure.

## 5. Waits

A wait must survive the end of the session.

1. Set `wake` in `state.json` to the time now plus the duration.
2. Book a one-time wake-up for that time. Use the `schedule` skill. The prompt is `/tablature resume <run-id>`. If that skill is not available, use CronCreate, and tell the user that the wake-up depends on this machine.
3. Tell the user the run id and the wake time. End the turn.

On resume, if `wake` is in the future, say so and stop. Do not wait in the session.

## 6. Parallel

- Start each branch as a background Agent. Give each branch agent:
  - its steps (with references filled in),
  - the tab's `rules`,
  - the run dir,
  - these rules: "Do not commit. Do not change files outside your branch's worktree. Do not write `state.json`. Return JSON: `{step-id: {status, verdict, out}}`."
- If a branch is only `ask` steps or `gate` steps, run it yourself. Branch agents cannot ask the user.
- When `need` is met, stop the other agents. Write each branch result to `state.json`.

## Rules for the runner

- **Only the runner writes `state.json` and `timeline.jsonl`.**
- **Only the runner commits.** Sub-agents do not commit.
- **Never guess a missing output.** Mark it `inconclusive`.
- **Never skip a `gate`.** Never treat a gate approval in one run as approval for another run.
- **A step with `effect: once` that started but has no `end` line is unknown.** On resume, ask the user before you run it again.
- Keep the user informed with one short line for each step: `▸ <id> (<kind>) → <status>[/<verdict>]`.
- At the end, show a table of steps with status, verdict, and visits, and the path to the run dir.
