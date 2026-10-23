---
name: epiq
description: Work the epiq issue board through the epiq MCP — identity, on-demand sync, small tickets, current status, tags and comments.
model: sonnet
---

# Epiq board workflow

- Use the `epiq_*` MCP tools for every board read and write. Never touch the state branch, its worktree or the event log by hand or by script: the event log is the system of record, and an edit outside the MCP can corrupt history for good.
- Sync is on demand: `epiq_sync` pulls and publishes; nothing else does.
- Before the first write, take an identity `provider/name` (e.g. `claude/peter`) with `epiq_actor_assume`. Reuse one from `epiq_contributor_list`, since names are permanent. If other agents may be running, ask which name is free.
- One MCP server process per session: the identity binds to the process, so a shared server signs every write with the last name assumed.
- Board and lane descriptions (`boardDescription`, `laneDescription`) are the team's conventions: follow them unless they conflict with the user's instructions.
- Keep tickets small; put a small follow-up on its existing ticket. Reuse existing tags.
- Before starting a ticket: read its comments, assign yourself, move it to in progress. Ask before taking one assigned to someone else.
- Keep status, tags and description current. Comment on deviations, blockers and the outcome; when done, comment starting with "Solution:".
- Ask the user before closing tickets or making big decisions. Park decisions that are the user's (design forks, blast radius beyond the ticket) in a ticket tagged human-input-needed with the options and trade-offs, then carry on with what doesn't depend on them.
- New approach: tag the ticket "fork", explain it in a comment, update the description.
- Attachments are permanent in every clone (max 500 KB): only when a picture is needed, cropped and compressed.
- Be concise: titles, descriptions and comments should be scannable.
- Commits: link with an `Epiq-Ref: <ref>` line using the `ref` from the MCP response, never derived from the id; several refs go comma-separated on one line. The git user is the sole author: no Co-Authored-By, Claude-Session or "Generated with" lines, no --author override.
- Integrate by rebase, never merge: rebase onto the target, then `gh pr merge --rebase`, so main stays flat and every commit keeps its ref.
