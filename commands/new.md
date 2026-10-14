---
description: Create a Gitstalk repository for this directory, connect it as origin and push the work as a first bean
argument-hint: "[owner/]name [--public] [--start <id>] [--description <text>]"
---

Create a Gitstalk repository from `$ARGUMENTS`, connect this directory to it and push its work
as the first bean. Follow the `gitstalk` skill, section "A new repository"
(`references/new-repo.md`).

Script: `sh "${CLAUDE_PLUGIN_ROOT}/scripts/gitstalk-setup.sh"` (on Windows without Git Bash:
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/gitstalk-setup.ps1"`,
same subcommands, options as `-Public`, `-Start`, `-Description`).

1. No name in `$ARGUMENTS`: ask for one (suggest this directory's name). Run `<script> verify`.
   If it fails, connect git first (`/gitstalk:setup`, the skill's "Connecting git"), then go on.
   `whoami: @<handle>` is the person.
2. **Ask the person first** (one question) when `--public` was given or the owner is not
   `<handle>` (an organization). Private in their own namespace needs no question.
3. In this directory: `git init` if it is not a repository. If there is no commit yet, look at
   `git status --short`, leave out anything secret (`.env`, keys, credentials; add them to
   `.gitignore`), stage the rest and commit with the intent: `Start <name>: <what it is>`.
   Uncommitted changes in an existing repository: ask whether to commit them first.
4. `<script> create <[owner/]name> [--public] [--start <id>] [--description <text>]`. It prints
   `created: <owner>/<name> (<visibility>)` and `web: <url>` (or `exists:` on 409: then confirm
   with the person that this is their repository before pushing to it), and sets `origin`.
   On `not allowed` or `invalid repository name`, report it and stop.
   (With the MCP server signed in, `repo_create` does the same; then `<script> remote <owner>/<name>`.)
5. Push the first commit as a bean, never to `stalk`, `sprout` or `main`:
   `git push origin HEAD:refs/heads/bean/<short-name>` (`<short-name>` like `start`). Read the
   `remote:` lines and follow their next step.
6. Report in two or three lines: the repository and its web URL, its visibility, and the
   bean's state.

Never print a token, `~/.git-credentials` or keychain contents, and never put a token in a URL.
