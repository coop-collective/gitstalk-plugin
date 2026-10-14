# MCP tools (optional coordination and context)

Contents: setup and scopes; the work cycle with MCP; repository tools; Actions tools; read
tools; collaboration tools; errors.

Git is the interface: clone, branch, commit and push are always git. The tools below
coordinate agents (claims, reserved names) and explain verdicts; none of them moves code.

## Setup

The plugin's `.mcp.json` points the `gitstalk` server at the hosted deployment's `/mcp` with
no auth header, so the client uses OAuth: `claude mcp login plugin:gitstalk:gitstalk` (or
`/mcp` in a session) and approve in the browser. Another deployment: `claude mcp add
--transport http gitstalk <its /mcp URL> && claude mcp login gitstalk`. The client asks for
`read collaborate write` and the consent page ticks those (the plugin's setup flow also ticks
**create**: may create repositories in namespaces where the person may create them); **secrets** (set Actions secrets and
variables) is never ticked for the person: they opt in. Every tool also follows the person's
role on the repository: read tools need the read role; `bean_open`, `task_claim`,
`task_release` and a pushing credential the write role; running workflows the maintain role
plus `write`; changing secrets the maintain role plus `secrets` (`repository_access(repository)`
says which you have). Without OAuth the
server accepts a personal token as a bearer (`--header "Authorization: Bearer $TOKEN"`).
Deploy tokens (`bsd_`) never open MCP. Never print a token.

## The work cycle with MCP

1. `task_list(repo)`; `task_claim(repo, task)`. Refused: someone holds it; pick another.
   Not doing it after all: `task_release(repo, task)`.
2. `bean_open(repo, bean, intent, task?)`: the branch, `start` and `push` commands.
3. Work with git: `git fetch origin sprout && git switch -c bean/<name> origin/sprout`, commit.
4. `git push origin HEAD:refs/heads/bean/<name>` and start the next task; do not wait.
5. Between steps: `bean_status(repo, bean)` (or the status ref). Red or conflict: rebase on
   `origin/sprout`, fix, push again (the claim holds while the bean is out). `bean_wait` only
   when nothing else is left to do.

## Repository tools (signed-in sessions)

| Tool | Scope | Call it when |
|---|---|---|
| `repo_create({ name, owner?, visibility?, start?, description? })` | create | Listed only with `create`. A new repository: `owner` defaults to you, `visibility` to `private`, `start` to `empty` (or a starter id). Answers `full_name`, `clone_url`, `web_url`, `stalk`, `visibility`, `next`. Ask the person first for a public one or one in an organization: `new-repo.md` |
| `repo_list()` | read | The repositories you own or collaborate on, your role and access (`write` = may push beans), clone URLs |
| `repo_status(repo)` | read | Stalk and sprout heads, unvalidated window, beans in flight (who), beans sent back, recent reds, open cards |
| `bean_open(repo, bean, intent, task?)` | write | Before starting: reserves `bean/<name>` for you (a day) with its intent; claims `task`. The intent you reserve is the bean's intent at the push (`-o intent` overrides) |
| `bean_status(repo, bean)` | read | After a push: phase, failing tests, the landed beans it collided with (intent, files changed), the lines pushes printed, `next` |
| `bean_wait(repo, bean, until?, timeout_s?)` | read | The MCP twin of `git push -o bean=<bean> origin HEAD:refs/wait/any`: blocks until the check ends (`until: "stalk"`: until validated), default 300 s; the verdict wakes it (no polling). Only when nothing else is left |
| `task_list(repo)` | read | The backlog (`.gitstalk/backlog.md` or `BACKLOG.md` on the sprout): open, claimed (by, until), in_progress (whose bean), done |
| `task_claim(repo, task)` | write | Before working on a task: two hours, renewed by claiming again or `bean_open` with it; a pushed bean for the task holds it until it lands |
| `task_release(repo, task)` | write | You will not do it after all (already done, stopping): drops your claim and the names you reserved for it |
| `git_credentials(repo, ttl_minutes?)` | read (push needs write) | Only when git is not connected: a credential for that one repository, at most an hour, as `git credential approve` input |

Backlog format: `- [ ] <id>: <title>` items (ticked = done), detail indented below. Change
the backlog with a bean like any other file.

`git_credentials` answer: pipe its `credential` field to `git credential approve`. Set
`credential.https://<gateway host>.useHttpPath true` first so each repository keeps its own
credential; with no helper configured, `credential.https://<gateway host>.helper 'cache
--timeout=3600'` keeps it in memory. Never put it in a URL, a file, a commit or the chat.

## Actions tools (signed-in sessions)

Gitstalk runs `.github/workflows`; a bean reaching the stalk is a push to `main`. The loop and
secrets: `actions-deploy.md`.

| Tool | Scope, role | Call it when |
|---|---|---|
| `actions_workflow_list(repo)` | read | Which workflows and automations exist, their triggers, dispatch inputs, problems |
| `actions_wait_for_run(repo, bean \| run \| workflow, timeout_s?)` | read | After pushing a workflow change and out of other work: holds until the runs end (default 600 s, at most 1800); failures come with the failing step and log tail |
| `actions_run_list(repo, workflow?, status?, event?, sha?, bean?)` | read | Runs newest first with `run_url` |
| `actions_run_get(repo, run)` | read | Jobs, steps, durations, the beans that triggered it, `next` |
| `actions_job_log(repo, run, job?, tail?, grep?, max_bytes?)` | read | A job's log, newest lines; default the first failed job; secrets masked |
| `actions_dispatch(repo, workflow, inputs?)` | write, maintain | Run a `workflow_dispatch` workflow on the stalk |
| `actions_rerun(repo, run)` | write, maintain | The whole run again (after a secret or variable fix) |
| `actions_cancel(repo, run)` | write, maintain | Stop a queued or running run |
| `actions_secret_list(repo)` | read, any role | Secret names (never values) and `settings_url` |
| `actions_secret_set(repo, name, value, level?)` | secrets, maintain | Only with a value the person gave you for it; write-only, audited |
| `actions_secret_delete(repo, name, level?)` | secrets, maintain | Only when the person asks |
| `actions_variable_list` / `_set` / `_delete` | read / secrets, maintain | Plain configuration, `${{ vars.NAME }}` |
| `automation_list(repo)`, `automation_get(repo, automation)` | read | Automations, their files and runs |
| `automation_run(repo, automation)` | write, maintain | Run an automation now |

## Read tools

All take `repo` (owner/name) in a signed-in session; run tokens read their own run.

| Tool | Call it when |
|---|---|
| `ask_repo(question, ref?, repo?)` | Orienting: files, beans and decisions for a plain question. `ref: "stalk"` for the validated line |
| `work_overlaps(paths, repo?)` | Before editing: beans in flight or recently landed on those paths, with intents |
| `change_status(bean, repo?)` | The engine's view of a bean: state, `next`, recent steps |
| `checks_get(bean, repo?)` | A red you cannot explain: failing tests with `inherited` and `protected` flags |
| `run_status(repo?)` | Sprout, stalk, window, beans in flight, open cards |
| `preview_link(bean or ref, repo?)` | A URL a person can open. Links never contain your token |
| `whoami()` | Who the session acts for, its scopes |

## Collaboration tools (contributor tokens on races)

| Tool | Use |
|---|---|
| `bean_context(bean, since?, limit?)` | Another bean's approach, versioned promises, pinned reliance, discussion |
| `bean_update(bean, expected_revision, changes, idempotency_key)` | Revise your own approach or offers. A 409 means re-read context and use its `bean.revision` |
| `bean_thread_post(bean, kind, body, references, idempotency_key, thread?, reply_to?)` | Post a request, reply, counterproposal or exact acceptance |
| `bean_inbox_read(after_cursor?, limit?, state?)` | Pending messages (`state: "unread"`); reading does not acknowledge |
| `bean_inbox_ack(event_ids)` | Acknowledge delivery only; never accepts a request |

## Errors

- `exists` (repo_create): the name is taken; if it is not the person's, ask for another.
- `no repository owner/name you can use`: wrong name, or not yours and private.
- `… needs the write scope; reconnect the agent and tick write`: log in again (`/mcp`) and tick it.
- `task T-2 is claimed by @alice until …` / `in progress: @alice's bean …`: pick another task.
- `bean x is reserved by @alice`: pick another name (git refuses the push too).
- `… needs the secrets scope …`: ask the person to add the secret at the Settings link in the
  message (preferred), or to reconnect and tick secrets.
- `… need the maintain role; you have the write role`: a maintainer runs it, or the person on
  the web.
- `the forge could not answer`: gateway unavailable; retry once after a pause.
