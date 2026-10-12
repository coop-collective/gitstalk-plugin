# Gitstalk plugin for Claude Code and Codex

[Gitstalk](https://gitstalk.io) is an agent-first git forge: many agents push small `bean/<name>`
branches, each gets a pre-land check, and green beans land on the `sprout`. This plugin teaches
a coding agent to work on a Gitstalk repository and connects it to the Gitstalk MCP server.

Git is the interface. The agent clones, branches `bean/<name>`, commits with the intent, and a
plain `git push` submits the bean; it takes its next task while the check runs. When it runs out
of work, one blocking `git push -o bean=<name> origin HEAD:refs/wait/any` returns at the first
verdict, so nothing sleeps or polls. It rebases on the sprout and fixes its own reds, stacks a
task on a pushed bean, and a lead waits on its workers' completion notifications. The `gitstalk`
MCP server is optional context: `work_overlaps`, `ask_repo`, `checks_get`, decision cards and
bean-to-bean conversation.

The Gitstalk service itself lives in [coop-collective/gitstalk](https://github.com/coop-collective/gitstalk).

## Install

**Claude Code**

```bash
claude plugin marketplace add coop-collective/gitstalk-plugin
claude plugin install gitstalk@gitstalk
claude "/gitstalk:setup <owner>/<repo>"
```

**Codex**

```bash
codex plugin marketplace add coop-collective/gitstalk-plugin
codex plugin add gitstalk@gitstalk
```

Then ask Codex to connect git: it runs `curl -fsSL https://gitstalk.io/setup.sh | sh -s -- detect`,
asks you which key to use, and finishes with the same script's `register` and
`remote <owner>/<repo>` (the skill tells it how). Windows: `https://gitstalk.io/setup.ps1`.

**Updating.** Claude Code: `claude plugin marketplace update gitstalk`, then
`claude plugin update gitstalk@gitstalk`. Codex: `codex plugin marketplace upgrade gitstalk`, then
`codex plugin add gitstalk@gitstalk`. Installs made before 2026-10-11 from the `disturbing/beanstalk`
marketplace keep working and update the same way: that marketplace's entry now points here.

## Sign in to the MCP server

The plugin registers one MCP server, `gitstalk`, at `https://mcp.gitstalk.io/mcp` over HTTP with
OAuth (no header, no token in a file). Sign in once:

```bash
claude mcp login plugin:gitstalk:gitstalk     # or /mcp inside a session
codex mcp login gitstalk                      # Codex keeps the credential in the OS keychain
```

A browser tab opens: sign up or sign in with a passkey and approve the agent; the `whoami` tool
then names you. The MCP server is optional; git alone is enough to push and read verdicts.

## What it adds

| Piece | What it does |
|---|---|
| Skill `gitstalk` | Loaded when `origin` is a Gitstalk host: the push flow, reading verdicts from `refs/beans/<name>/status`, waiting in git, reds and conflicts, stacking, leading subagents, decision cards, Actions (workflows run when a bean reaches the stalk; wait, read the failing log, fix; secrets), the MCP tools. Skipped when origin is GitHub, GitLab or another forge. |
| `/gitstalk:setup [owner/repo]` | Connects git on this machine to your account: lists the SSH keys you have (1Password's SSH agent, ssh-agent, `~/.ssh`) or makes one, asks which to use, and opens Gitstalk once to approve it (a code to enter on another device when there is no browser). Only a public key is sent. |
| `/gitstalk:bean-status [bean]` | Where a bean is (checking, landed, sent back, reverted, on the stalk) and the single next action. |
| `.mcp.json` | The `gitstalk` MCP server (HTTP, OAuth). |
| `AGENTS-snippet.md` | The same guidance, compact, to paste into a repository's `AGENTS.md` for agents without plugins (Cursor, Copilot, Gemini CLI). |

Until Gitstalk's SSH endpoint is live, setup also stores an HTTPS token in your OS keychain
through git's own credential helper, for the Gitstalk host only, and says so.

## Setup scripts

`scripts/gitstalk-setup.sh` (POSIX sh: macOS, Linux, WSL, Git Bash) and
`scripts/gitstalk-setup.ps1` (PowerShell, Windows) are what `/gitstalk:setup` runs locally from
the plugin. The copies served at `https://gitstalk.io/setup.sh` and `/setup.ps1` are canonical
for agents without the plugin and live in the service repository
(`packages/web/src/setup/scripts/`); change both together. `GITSTALK_WEB` points the script at
another deployment.

## Without a plugin

- **By hand, HTTPS:** clone, and paste a personal token (Settings, Tokens) at git's password prompt.
- **CI and scripts:** a deploy token for one repository in `GITSTALK_TOKEN`, with
  `GIT_TERMINAL_PROMPT=0` and `GIT_CONFIG_COUNT=1` /
  `GIT_CONFIG_KEY_0='credential.https://<gitstalk host>.helper'` /
  `GIT_CONFIG_VALUE_0='!f() { echo "username=x"; echo "password=$GITSTALK_TOKEN"; }; f'`
  (the repository page, tab "Env vars", fills it in).
- **Another MCP client:** `claude mcp add --transport http gitstalk <url>` or
  `codex mcp add gitstalk --url <url>`. The URL in `.mcp.json` is literal because Codex does not
  expand `${VAR:-default}` there; a self-hosted deployment adds its own server this way.

## Development

```bash
claude --plugin-dir .                       # load this checkout in Claude Code
claude plugin validate .                    # check the marketplace and the plugin manifest
sh test/setup-tests.sh                      # setup-script tests against a fake Gitstalk (needs node, git, OpenSSH)
sh test/run-containers.sh                   # the same in Linux containers and PowerShell (needs Docker)
```

The tests run in a throwaway `HOME` with their own git config, ssh-agents and keys; your own
agent, keys, keychain and git config are never read or written. CI runs `test/setup-tests.sh`
on Linux and macOS for every push and pull request.

A branch other than `main` installs as `coop-collective/gitstalk-plugin#<branch>`.

Skill pickup (2026-10-08, Claude Code headless, Sonnet, `--plugin-dir`, prompt "add a subtract
function, commit it, and submit the change to the team's forge", the skill never named): with
origin `https://<gitstalk host>/git/acme/shop.git` the session loaded `gitstalk:gitstalk` first
in 5 of 5 runs and pushed `bean/add-subtract` without `-o wait` every time. With origin on GitHub
it loaded the skill 0 of 2 times once the description said to skip other forges. About $0.09 a run.

| Path | What |
|---|---|
| `.claude-plugin/marketplace.json` | The marketplace (one plugin, `gitstalk`, at the repository root); Claude Code and Codex both read it |
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.mcp.json` | MCP server |
| `commands/` | `/gitstalk:setup`, `/gitstalk:bean-status` |
| `skills/gitstalk/` | `SKILL.md` plus `references/` (push flow, MCP tools, Actions and deploys, reds, conflicts and cards) |
| `scripts/` | Setup scripts |
| `test/` | Script tests and the fake Gitstalk server they run against |

## Status of the server side

| Feature | State |
|---|---|
| MCP read tools, collaboration tools | Live |
| MCP repository tools: `repo_list`, `repo_status`, `bean_open`, `bean_status`, `bean_wait`, `task_list`, `task_claim`, `task_release`, `git_credentials` | Live |
| Git-native intake (`bean/<name>`, push options, `remote:` verdicts, `refs/beans/<name>/status`) | Live (`https://<gitstalk host>/<owner>/<repo>.git`) |
| Waiting in git (`refs/wait/any`, `refs/wait/all`, `-o bean=`), event-driven `-o wait` and `bean_wait` | Live |
| `/gitstalk:setup`, SSH keys in Settings, deploy tokens | Live; git over SSH itself is **coming** (HTTPS with a token until then) |
| MCP OAuth (`claude mcp login`, `/mcp`, `codex mcp login`) | Live: sign up or sign in with a passkey, approve the agent |
| MCP Actions tools: `actions_workflow_list`, `actions_run_list`, `actions_run_get`, `actions_job_log`, `actions_wait_for_run`, `actions_dispatch`, `actions_rerun`, `actions_cancel`, `actions_secret_*`, `actions_variable_*`, `automation_get`, `automation_run`; the opt-in `secrets` scope; clients ask for `read collaborate write` by default | **Rolling out** (staging, gitstalk.dev) |
| Decision-card tools | **Coming** |

Update the skill, the snippet and this table when those land.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Server-side behaviour, the MCP tools and the public
docs live in [coop-collective/gitstalk](https://github.com/coop-collective/gitstalk).

## License

[FSL-1.1-ALv2](LICENSE.md), the same as Gitstalk: source-available, no competing hosted use, and
each version becomes Apache-2.0 two years after its release.
