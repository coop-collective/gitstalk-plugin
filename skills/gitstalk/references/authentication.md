# Connect terminal git (Claude Code and Codex)

MCP OAuth authorizes tools, not terminal git. `codex mcp login` can succeed while git's OS
credential helper still uses another account. A registered public key is separate again:
setup uses it for registration, but only an advertised SSH endpoint accepts SSH git traffic.

## Choose the script and host

Use the installed plugin's bundled script. From this skill directory, its relative path is
`../../scripts/gitstalk-setup.sh`; resolve an absolute path from the `SKILL.md` path supplied
by the host. On Windows without a POSIX shell, use `gitstalk-setup.ps1` alongside it.
Codex can run the script directly; it does not need `/gitstalk:setup`, `AskUserQuestion`, or
`${CLAUDE_PLUGIN_ROOT}`. If no bundled script is available, download `<web>/setup.sh` once to
a temporary file and run it with `sh` (PowerShell: `<web>/setup.ps1`).

The commands below use `setup` as shorthand for `sh /absolute/path/gitstalk-setup.sh`, not
as an installed executable. Use the actual deployment: `GITSTALK_WEB`, a saved `host`, or
the default gitstalk.io. The script's `detect` reads `<web>/api/setup` and reports the git
origin and SSH host. Check that the MCP connection belongs to that deployment too.

## Diagnose before replacing anything

1. Use MCP `whoami()` and `repo_list()` (or `repository_access`) when available to establish
   the intended person, repository, and clone URL. Do not guess an owner from a local username.
2. Run `setup detect`, then `setup verify owner/repo`. `verify` prints only `whoami:` and
   whether `ls_remote:` succeeded; it handles the stored token internally. Do not inspect
   `git credential fill`, keychain contents, or credential files in tool output.
3. Compare git's `whoami:` with the intended MCP person. Repository ownership can differ
   legitimately for collaborators; compare identities, not just the repository owner.
   A different handle explains why MCP sees a private repository while git says `no repository`
   or `repository ... not found`. Those errors are authentication/access candidates, alongside
   `Authentication failed`, disabled prompts, and `could not read Username`.
4. A successful verification needs no setup. If the account matches but access fails, check
   the clone URL and repository permissions. Do not loop through keys or create a replacement
   repository because a private one returned 404.

## Reuse the key and finish setup

- If the user already selected a key, reuse it (for example `~/.ssh/gitstalk_ed25519.pub`).
  Creating a key, finding its `.pub`, or finding a remembered key does not prove approval
  was completed for this account. Do not generate another key or repeat the selection question.
- If no key was selected, use `detect`'s options and ask once with the host's question tool.
  Generate only when needed. Send only public keys, never private key material.
- Run `setup register --key /path/to/existing.pub`, or
  `setup register --agent-key <fingerprint> --agent <socket>`. Windows uses `-Key`,
  `-AgentKey`, and `-Agent`. Tell the person to check the account, code, and fingerprint on
  the browser approval page. Reconnection must be approved as the intended person, not the
  account that happens to be signed in. Keep the long-running command alive using the host's
  process/session tool while the person approves; do not restart registration to poll it.
- When `ssh_host` is empty/null, setup requests an HTTPS token during approval and stores
  it through git's credential helper. The existing private key is not used to sign HTTPS
  git requests. Keep the HTTPS clone URL; do not guess `git@...`, an SSH port, or a host.
  When `ssh_host` is present, `setup remote` configures the advertised SSH transport.
- After `approved:`, run `setup verify owner/repo` and confirm the intended account and
  `ls_remote: owner/repo ok`. Then run `setup remote owner/repo /absolute/destination`
  to clone, or `setup remote owner/repo` inside an existing clone to set origin. Resume the task.

Changing the MCP login alone does not update git's saved account. Registration may replace
the saved credential for this Gitstalk host; explain that when correcting an account mismatch.
No change to other hosts' git configuration is needed.

## Temporary MCP credential fallback

If git access fails and browser/keychain setup cannot be completed in this environment,
`git_credentials(repo, ttl_minutes?)` provides a credential for that repository, at most an
hour. It inherits the MCP person's access and is not SSH authentication or a permanent fix.

In Codex code mode, keep the tool result inside the orchestration call: parse the `credential`
field and feed it to `git credential approve` over non-echoing stdin. Never pass the full
result to `text()`/`notify()`, put credentials in shell arguments or URLs, or write them to
a temporary file. Retain the returned protocol, host and path; apply `credential.useHttpPath=true`
consistently when approving and using it. Prefer the existing OS helper and scope overrides
to the target host/repository, leaving unrelated saved accounts intact.

If an in-memory git credential cache is necessary, its socket must live in a private directory
created with `mktemp -d` (mode 0700), not directly in `/tmp`; never change `/tmp` permissions.
Agent process cleanup can terminate a cache daemon between tool calls. Confirm the next git
operation succeeds in the same live session rather than repeatedly approving into a dead cache.
Report the temporary lifetime and the remaining durable setup accurately.
