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

Then ask Codex to connect git. It runs the bundled `scripts/gitstalk-setup.sh` directly,
reuses your selected key (or asks once), and completes `register`, `verify <owner>/<repo>`
and `remote <owner>/<repo>`. Windows: `scripts/gitstalk-setup.ps1`. The shared
[authentication guide](skills/gitstalk/references/authentication.md) is loaded from the skill;
Codex does not need Claude Code's slash commands or environment variables.

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
Another deployment: see [Custom host](#custom-host-self-hosted-local-staging).

**MCP sign-in and terminal git are separate.** Logging in to MCP does not update git's
saved credential or authorize an SSH key. If MCP lists a private repository but cloning
says `no repository` or `not found`, compare MCP `whoami()` with setup's
`verify <owner>/<repo>`. A stale git login may belong to another account. Reuse the existing
key and complete registration in the browser as the intended account, then verify again.
See the [authentication guide](skills/gitstalk/references/authentication.md).

## What it adds

| Piece | What it does |
|---|---|
| Skill `gitstalk` | Loaded when `origin` is a Gitstalk host: the push flow, reading verdicts from `refs/beans/<name>/status`, waiting in git, reds and conflicts, intent rechecks, stacking, leading subagents, decision cards, Actions (workflows run when a bean reaches the stalk; wait, read the failing log, fix; secrets), the MCP tools. Skipped when origin is GitHub, GitLab or another forge. |
| `/gitstalk:setup [owner/repo]` | Connects git on this machine to your account: lists the SSH keys you have (1Password's SSH agent, ssh-agent, `~/.ssh`) or makes one, asks which to use, and opens Gitstalk once to approve it (a code to enter on another device when there is no browser). Only a public key is sent. |
| `/gitstalk:new [owner/]name [--public]` | Creates a Gitstalk repository (private unless you ask; it asks you first for a public one or one in an organization), connects this directory as `origin` and pushes its work as the first bean. Uses the token git already keeps, through the setup script's `create` subcommand. |
| `/gitstalk:host <url>` | Uses a custom host (self-hosted, local or staging) for git setup and the MCP server, saved across sessions; `--reset` goes back to gitstalk.io. |
| `/gitstalk:bean-status [bean]` | Where a bean is (checking, landed, sent back, reverted, on the stalk) and the single next action. |
| `.mcp.json` | The `gitstalk` MCP server (HTTP, OAuth) at the plugin's `mcp_url` option (default `https://mcp.gitstalk.io/mcp`). Codex reads `.codex-plugin/plugin.json` and the literal `.codex-mcp.json` instead. |
| `AGENTS-snippet.md` | The same guidance, compact, to paste into a repository's `AGENTS.md` for agents without plugins (Cursor, Copilot, Gemini CLI). |

Until Gitstalk's SSH endpoint is live, setup also stores an HTTPS token in your OS keychain
through git's own credential helper, for the Gitstalk host only, and says so. An empty/null
`ssh_host` from `/api/setup` means there is no SSH transport to use: registering a public key
does not enable it, and the private key does not sign HTTPS git requests.

## Setup scripts

`scripts/gitstalk-setup.sh` (POSIX sh: macOS, Linux, WSL, Git Bash) and
`scripts/gitstalk-setup.ps1` (PowerShell, Windows) are what `/gitstalk:setup` runs locally from
the plugin. The copies served at `https://gitstalk.io/setup.sh` and `/setup.ps1` are canonical
for agents without the plugin and live in the service repository
(`packages/web/src/setup/scripts/`); change both together. The scripts use `GITSTALK_WEB`, else
the host saved with `host <url>`, else `https://gitstalk.io` (see Custom host).

`create [owner/]name [--public] [--start <id>] [--description <text>]` creates a repository with
the HTTPS token git already keeps for the Gitstalk host (read through `git credential fill`,
handed to curl on stdin, never printed or put on a command line), calls `POST <web>/api/repos`,
prints `created: <owner>/<name> (<visibility>)` and `web: <url>`, and then connects `origin` as
`remote` does. A 409 says the repository exists and still connects it. `register` asks for the
`create` scope along with read and write.

## Custom host (self-hosted, local, staging)

By default everything talks to `https://gitstalk.io` and its MCP server
`https://mcp.gitstalk.io/mcp`. To use another deployment, such as staging at
`https://gitstalk.dev` or a local one at `http://localhost:5173`:

```bash
/gitstalk:host https://gitstalk.dev        # in Claude Code; /gitstalk:host --reset goes back
```

It runs `gitstalk-setup.sh host <url>`, which checks that `<url>/api/setup` answers and saves
the host in `~/.config/gitstalk/host` (`$XDG_CONFIG_HOME`; `%APPDATA%\gitstalk\host` for the
PowerShell script). Every later `detect`, `register`, `remote`, `create` and `verify` uses it.
The order is `GITSTALK_WEB` (one shell or one run), then the saved host, then gitstalk.io;
`detect` prints `web: <url> (<why>)`. The command then saves the host's MCP URL (from
`/api/setup`) in the plugin's `mcp_url` option with
`claude plugin configure gitstalk@gitstalk --values-stdin`. Claude Code keeps it in your user
settings, and `/config` shows it. Restart Claude Code and run `/mcp` to sign in on that host,
then run `/gitstalk:setup` once to connect git there (each host has its own accounts and tokens).
Without the plugin: `curl -fsSL <url>/setup.sh | sh -s -- host <url>`, then
`claude mcp add --transport http gitstalk <url's mcp_url>`.

`detect` and `verify` print one `mcp:` line when the host's MCP server is not the production
one and was not saved with `host`, naming the `/gitstalk:host` command to run.

**Two servers, the same tools.** If you also added a Gitstalk MCP server by hand
(`claude mcp add … gitstalk-dev …`) while the plugin's server is connected, both offer the same
tool names and an agent may call the wrong host. Disable one of them in `/mcp`.

**Codex** has no plugin options, so its plugin server stays on production. For another host,
run `codex mcp add gitstalk-<name> --url <mcp_url>`, then `codex mcp login gitstalk-<name>`,
and turn the plugin's server off in `~/.codex/config.toml` with
`[plugins."gitstalk@gitstalk".mcp_servers.gitstalk]` and `enabled = false`. The setup script's saved host works
the same under Codex.

**Debugging Actions against a custom host.** Actions run on whichever host the bean is pushed
to, so check both halves point at it. `git remote get-url origin` should name the custom host,
and `verify owner/repo` should say `whoami:`. `whoami` in MCP should name the same account.
Push a bean, then call `actions_wait_for_run(repo, bean)` and `actions_job_log` for the failing
step, as on production. An empty run list usually means the MCP server and `origin` are on
different hosts (check `/mcp` for a second Gitstalk server), or the workflow's `on:` does not
match (`push` to `main` runs once the bean lands). The Actions tools are rolling out on staging
first (see the status table).

## Creating repositories

Agents and people create repositories three ways, each needing the `create` scope ("may create
repositories in namespaces where the person may create them"; setup asks for it):

- MCP `repo_create({ name, owner?, visibility?, start?, description? })`: owner defaults to
  you, visibility to private, start to `empty`. Listed only for sessions with `create`.
- `POST <web>/api/repos` with `Authorization: Bearer <personal token with create>` (what the
  setup script's `create` and `/gitstalk:new` use): 201, 409 `exists`, 403 not allowed, 422
  invalid name.
- Push to create: `git push` to `https://<host>/<owner>/<name>.git` that does not exist
  creates it, private, and prints its web URL in `remote:` lines. A name used before or renamed
  away is refused; a credential without `create` gets a hint to use `repo_create` or `<web>/new`.

The skill tells agents to ask the person first before creating a public repository or one in an
organization, and to push the first work as a bean, never to the stalk.

## Without a plugin

- **By hand, HTTPS:** clone, and paste a personal token (Settings, Tokens) at git's password prompt.
- **CI and scripts:** a deploy token for one repository in `GITSTALK_TOKEN`, with
  `GIT_TERMINAL_PROMPT=0` and `GIT_CONFIG_COUNT=1` /
  `GIT_CONFIG_KEY_0='credential.https://<gitstalk host>.helper'` /
  `GIT_CONFIG_VALUE_0='!f() { echo "username=x"; echo "password=$GITSTALK_TOKEN"; }; f'`
  (the repository page, tab "Env vars", fills it in).
- **Another MCP client:** `claude mcp add --transport http gitstalk <url>` or
  `codex mcp add gitstalk --url <url>`. Codex substitutes neither `${VAR}` nor
  `${user_config.*}` in a plugin's MCP file, so it gets its own manifest
  (`.codex-plugin/plugin.json`) with a literal URL (`.codex-mcp.json`).

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
| `.claude-plugin/plugin.json` | Plugin manifest for Claude Code (with the `mcp_url` option) |
| `.codex-plugin/plugin.json`, `.codex-mcp.json` | Codex's manifest (same metadata and version) and its MCP server at a literal URL |
| `.mcp.json` | MCP server for Claude Code (`${user_config.mcp_url}`) |
| `commands/` | `/gitstalk:setup`, `/gitstalk:new`, `/gitstalk:host`, `/gitstalk:bean-status` |
| `skills/gitstalk/` | `SKILL.md` plus `references/` (push flow, MCP tools, Actions and deploys, new repositories, reds, conflicts and cards) |
| `scripts/` | Setup scripts |
| `test/` | Script tests and the fake Gitstalk server they run against |

## Status of the server side

| Feature | State |
|---|---|
| MCP read tools, collaboration tools | Live |
| MCP repository tools: `repo_list`, `repo_status`, `bean_open`, `bean_status`, `bean_wait`, `task_list`, `task_claim` (with `release: true` to give one back), `git_credentials` | Live |
| Git-native intake (`bean/<name>`, push options, `remote:` verdicts, `refs/beans/<name>/status`) | Live (`https://<gitstalk host>/<owner>/<repo>.git`) |
| Waiting in git (`refs/wait/any`, `refs/wait/all`, `-o bean=`), event-driven `-o wait` and `bean_wait` | Live |
| `/gitstalk:setup`, SSH keys in Settings, deploy tokens | Live; git over SSH itself is **coming** (HTTPS with a token until then) |
| MCP OAuth (`claude mcp login`, `/mcp`, `codex mcp login`) | Live: sign up or sign in with a passkey, approve the agent |
| MCP Actions tools: `actions_workflow_list`, `actions_run_list`, `actions_run_get`, `actions_job_log`, `actions_wait_for_run`, `actions_dispatch`, `actions_rerun`, `actions_cancel`, `actions_secret_*`, `actions_variable_*`, `automation_get`, `automation_run`; the opt-in `secrets` scope; clients ask for `read collaborate write` by default | **Rolling out** (staging, gitstalk.dev) |
| Creating repositories: the `create` scope, `repo_create`, `POST /api/repos`, push-to-create; `setup.sh create`, `/gitstalk:new` | **Rolling out** (staging, gitstalk.dev; server PR `repo-create` in coop-collective/gitstalk) |
| Decision-card tools | **Coming** |

Update the skill, the snippet and this table when those land.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Server-side behaviour, the MCP tools and the public
docs live in [coop-collective/gitstalk](https://github.com/coop-collective/gitstalk).

## License

[MIT](LICENSE). Copyright 2026 Coop. "Gitstalk" and its logo are trademarks and are not licensed by
the MIT License; see [TRADEMARKS.md](https://github.com/coop-collective/gitstalk/blob/main/TRADEMARKS.md) in the Gitstalk repository.
