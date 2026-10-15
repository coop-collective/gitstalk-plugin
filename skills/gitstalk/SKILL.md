---
name: gitstalk
description: Clone, authenticate, create and work on Gitstalk repositories. Use when the user names Gitstalk, asks to connect a Gitstalk SSH key or check out a Gitstalk repo (even before origin exists), or origin is a Gitstalk host or has sprout and stalk branches. Covers bean branches, commits, pushing and landing, reds and conflicts, protected tests, teams, MCP coordination, and GitHub Actions workflows and Cloudflare deployment secrets. For an existing checkout, inspect origin; skip unrelated repositories on GitHub, GitLab or other forges.
---

# Working on a Gitstalk repository

Git is the interface; the MCP server is optional context. Git must be connected (below).

Words: a **bean** is one small change on a branch `bean/<short-name>`. The **sprout** is the
latest integrated state (every landed bean); build on it. The **stalk** is the validated line
behind it. `main` is never yours. The forge's remote is `https://<gitstalk host>/<owner>/<repo>.git`.

## Connecting git

Before a first clone or after an authentication failure, read [authentication.md](references/authentication.md).
MCP OAuth and terminal git have separate credentials and may name different accounts. A
private-repo `not found` can mean the wrong git account even when MCP lists the repo.
Codex runs the bundled `../../scripts/gitstalk-setup.sh` relative to this skill directory;
`/gitstalk:setup` and `${CLAUDE_PLUGIN_ROOT}` are Claude Code conveniences. Reuse the chosen
key. `ssh_host: null` means HTTPS with a stored token; registering a key does not enable SSH.
Never request tokens in chat or put them in URLs. CI uses `GITSTALK_TOKEN` plus `GIT_CONFIG_*`.

## A new repository
MCP `repo_create(name, visibility?, owner?, start?, description?)` (`create` scope), or
`/gitstalk:new <name>` (sets `origin` too), or a first `git push` to a new name: private by
default. **Ask the person first** to make one public or to create one in an organization. Then
push work as beans, never to the stalk: `references/new-repo.md`.

## The flow: push, then keep working

```bash
git fetch origin sprout && git switch -c bean/<short-name> origin/sprout
# work; commit. The message is the intent: why, with units and assumptions stated
git commit -m "Retry webhook delivery on 5xx" -m "Task: t032"
git fetch origin sprout && git rebase origin/sprout      # if the sprout moved
git push origin HEAD:refs/heads/bean/<short-name>        # submits the bean; returns in seconds
git fetch origin sprout && git switch -c bean/<next> origin/sprout   # next task, now
```

A plain push returns as soon as the bean is received. The forge then merges it onto the sprout
and runs the whole suite (about a minute). **Never wait on your own check while you have work,
and never `sleep` to poll the forge.** Start the next task at once. Between steps (after a
commit, before a new task) a quick look costs nothing:

```bash
git fetch -q origin '+refs/beans/*:refs/beans/*'
git for-each-ref 'refs/beans/<a>/' 'refs/beans/<b>/' --format='%(refname:lstrip=2) %(contents:subject)'
```

The subject is `<phase>: <reason>`: `checking`, `landed`, `green` (on the stalk), `red`,
`conflict`, `parked`, `dropped`.

**Out of work: one blocking call that the verdict wakes.** Name your beans:

```bash
git push -o bean=<a> -o bean=<b> origin HEAD:refs/wait/any   # returns at the first verdict
git push -o bean=<a> -o bean=<b> origin HEAD:refs/wait/all   # returns when none is checking
```

A push to `refs/wait/any|all` stores nothing. The forge holds it and prints each verdict as it
arrives (`verdict for <bean>: landed|red|conflict`, with the failing tests or hunks), then
`your beans: ...` and the next step. It returns at once when one of them is already red or in
conflict, or none is checking. Without `-o bean=` it covers every bean in flight pushed with your
credential, which subagents share, so workers name their own. It holds up to 9 minutes
(`-o wait=<s>`, at most 1800); in Claude Code give that Bash call `timeout: 600000`. Loop:
wait-any, react (fix a red and push it again), wait-any again; before you finish, `refs/wait/all`
until every bean is `landed` or handed back. MCP `bean_wait` does the same for one bean.

`git push -o wait origin HEAD:refs/heads/bean/<name>` submits and blocks in one step: only when
your very next step needs that verdict. Pushing the same commit again does nothing (git says
"Everything up-to-date"); to re-attach to a bean in check, wait on it as above.

A red or conflict comes back to **you**, its author: commit your work in progress, `git switch
bean/<name>`, rebase on `origin/sprout`, fix, `git push -f origin HEAD:refs/heads/bean/<name>`,
and switch back. A new commit to a bean still being checked is refused (the message says how to
wait for its verdict); its verdict comes first.

**Stacking.** A task that needs your pushed, not yet landed bean starts on it (`git switch -c
bean/<child> bean/<parent>`) and is pushed after the parent lands, rebased with `git rebase
--onto origin/sprout bean/<parent>`; a red parent first: `references/push-flow.md`.

**Teams.** When you split work among subagents, each one pushes its own beans from its own
worktree, owns their reds, and when out of tasks waits with `refs/wait/any` naming its beans;
the lead does not push for them. **A lead never sleeps or polls.** In Claude Code, start
workers with the Agent tool in the background (`run_in_background: true`), then end your turn:
Claude Code starts your next turn with a notification each time a worker finishes (`claude -p`
stays alive for them, but stops them 10 minutes after your last turn unless it runs with
`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`). On each notification read the report, start the
next worker if work remains, and end your turn again. After the last worker has reported, one
`git push origin HEAD:refs/wait/all` (every bean of the shared credential), then report. Push
options and every `remote:` line: `references/push-flow.md`.

## Rules

- One intent per bean; keep it small (a handful of files). Split unrelated work into more beans.
- Never push to `sprout`, `stalk` or `main`; the remote refuses. Never force-push another bean.
- Rebase on `origin/sprout` before pushing whenever it moved; a stale base causes conflicts.
- **Acceptance tests are protected**: yours (write them with the change) and landed beans'.
  Never edit, delete, skip or weaken one to get green. You may update other existing tests
  only when your change intentionally alters their expectations; say so in the commit message.
- Never print or commit the credential, and do not paste `git remote -v` output that holds it.
- Before you push: `git diff origin/sprout --stat` shows only this intent's files; your tests
  pass, protected tests untouched; the message states the intent; rebased on `origin/sprout`.

## Reading results

The status ref above (or `git cat-file -p refs/beans/<name>/status` for the full verdict, or the
`remote:` lines of a wait). Step by step: `references/reds-conflicts-cards.md`.

| Verdict | Meaning | Do |
|---|---|---|
| checking | Pre-land check is running | Work on something else. Do not push this bean again |
| landed / green | On the sprout / validated on the stalk | Done. Report it |
| red | Your change plus the sprout fails tests | Read failing tests, the bean you collided with and its intent. Rebase, fix the code, push again |
| conflict | Same lines as a landed bean | Rebase on `origin/sprout`; keep both intents; push again |
| red: recheck | Clef thinks your intent clashes with a bean you never saw (landed after you forked, or still in check) | Read that bean; if they disagree, fix yours so both hold. Rebase, push with trailer `Intent-checked: <bean>`. Never edit the other bean |
| inherited red | The sprout was already red on that test | Not yours; do not "fix" it; wait, rebase, retry |
| decision card open | A person decides between two beans' intents | Wait; do not work around it. Relay any "Before approving: Clef also thinks…" to your person; never approve |
| reverted / dropped | Broke the sprout validation, or gave up | Read the reason; start a new bean if still needed |

## Actions: workflows run here

Gitstalk runs GitHub Actions workflows (`.github/workflows/*.yml`, GitHub's syntax). A bean
reaching the stalk **is a push to `main`**, so `on: push: branches: [main]` deploys after your
bean lands and validates; `workflow_dispatch` and `schedule` work too, `pull_request` not yet.
Never tell the person Gitstalk does not run Actions. The loop: push the bean, then
`actions_wait_for_run(repo, bean)` (holds until its runs end; answers each conclusion with the
failing step and its log tail), `actions_job_log` for more, fix in a new bean, push, wait again.
Secrets: `actions_secret_list` shows names; ask the person to add a missing one in Settings →
Secrets and variables (the answer has the link). `actions_secret_set` only with a value the
person gave you for it; never invent, read from a file or print one. `references/actions-deploy.md`.

## When to call MCP (optional)

Git does the work; MCP (`/mcp`, OAuth login) coordinates it and adds context git cannot
give. Tools take the repository as `repo: "owner/name"`.

- **Before starting:** with a backlog, `task_list` then `task_claim` (`release: true` gives one
  back); `bean_open(repo, bean, intent, task?)` reserves the name; `work_overlaps(paths, repo)`
  shows who is editing those files.
- **After pushing:** `bean_status` (failing tests, the bean you collided with, next step);
  `bean_wait` blocks until the check ends: only when you have nothing else to do.
- **Credentials:** when git cannot access the repo and browser setup is unavailable:
  `git_credentials(repo)` gives a temporary repo credential; [authentication.md](references/authentication.md).
- **Conversation:** use `bean_context`, `bean_thread_post`, `bean_inbox_read` when approaches contradict.

Never use MCP to move code. Tools and scopes: `references/mcp-tools.md`.
