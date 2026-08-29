# Agent Instructions

## Tyrion is authoritative for new work

StreamWeaver uses **Tyrion** as the source of truth for all new stories, discoveries,
plans, claims, gates, and completion evidence.

At session start or after compaction:

```bash
tyrion prime
tyrion status
```

Before implementation, read the project and epic context, then claim exactly one story:

```bash
tyrion project show
tyrion epic show
tyrion claim-next                 # resume-safe: re-adopts your lane's in-flight story
# or: tyrion start <story-slug>   # when the user named a specific story
tyrion resume <story-slug>
```

Use the `tyrion-implement` skill for the full implementation loop. Record plans,
progress, discoveries, criterion evidence, pre-push/UAT gates, and completion in
Tyrion as the skill directs. New work is added through a reviewed feature/story flow
(`tyrion-add-story`, `tyrion-shape` + `tyrion-import`, or an equivalent reviewed
`.feature` update), never through an ad-hoc TODO list or another tracker.

Do not query Tyrion's SQLite database directly. Use the CLI. If a required read is not
available through the CLI, record that as a Tyrion discovery rather than coupling code
or agent instructions to the internal schema.

## Beads is a legacy backlog only

Historical unresolved Beads items remain available so they can be understood and
closed. Beads is **not** a source for selecting, claiming, or creating new work.

Allowed for existing issue IDs only:

```bash
bd list --status=open
bd search "<term>"
bd show <existing-id>
bd update <existing-id> ...
bd close <existing-id> --reason="<resolution or Tyrion replacement>"
```

Never run `bd create`, `bd ready`, `bd update --claim`, or `bv` to choose new work.
When an existing Beads item still matters, create/reuse a Tyrion story or discovery,
link the old Beads ID in a Tyrion note, then close the legacy item when resolved.

## Git and session completion

- Stage explicit paths only. Never use `git add -A`, `git add .`, or `git add -u`.
- Run the quality gate required by the active Tyrion story and record every gate run.
- Do not commit until the story's required criterion evidence is recorded.
- Close or checkpoint the Tyrion story before ending the session.
- Push completed work to the remote; verify `git status` reports the branch is up to date.
- Existing unrelated/untracked files belong to other work. Do not stage, delete, or rewrite them.

## Non-interactive shell commands

Always use non-interactive flags for commands that may prompt:

```bash
cp -f source dest
mv -f source dest
rm -f file
rm -rf directory
cp -rf source dest
```

- `scp`: use `-o BatchMode=yes`
- `ssh`: use `-o BatchMode=yes`
- `apt-get`: use `-y`
- `brew`: use `HOMEBREW_NO_AUTO_UPDATE=1`

## UKF — Universal Knowledge Facade

Search the federation before researching or re-deriving durable knowledge:

```bash
uregistry list --kind wiki
ukf search "<term>"
```

Read the returned source before proposing a duplicate design. File durable research,
decisions, and reusable patterns in the appropriate UKF member. Keep verified records,
proposals, and user decisions visibly distinct.
