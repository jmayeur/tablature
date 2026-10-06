---
name: mermaidify
description: Draw a tablature flow (.tab file) as a Mermaid flowchart, or refresh the flow diagrams in a Markdown doc. Use when the user says "mermaidify", "diagram this tab", "draw the flow", or "update the diagrams".
argument-hint: "<file.tab> | --update <doc.md>"
---

# Mermaidify

Do not write the diagram by hand. Run the script in this skill's folder. It is deterministic, so the same tab always gives the same diagram.

| Ask | Run |
|---|---|
| Draw one tab | `ruby ${CLAUDE_SKILL_DIR}/mermaidify.rb --fence <file.tab>` |
| Refresh a doc | `ruby ${CLAUDE_SKILL_DIR}/mermaidify.rb --update <doc.md>` |

- To draw: show the fenced output to the user as is.
- To refresh: each block between `<!-- mermaidify: <path.tab> -->` and `<!-- /mermaidify -->` is replaced. Paths are relative to the doc. To add a diagram to a doc, add an empty marker pair first.
- If the script fails, show the error. The usual cause is a YAML problem in the tab, for example `on:` (use `route:`) or an unquoted `: `. Do not change the tab unless the user asks.

Key for the user:

- Blue: deterministic (script, shell, MCP)
- Purple: agentic (skill, agent prompt)
- Orange: human choice
- Green: sub-flow
- Grey: durable wait
- 🔒: needs approval
- `max`: loop limit
