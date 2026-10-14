---
description: Use a custom Gitstalk host (self-hosted, local or staging) for git setup and the MCP server, saved across sessions
argument-hint: "<url> | --reset"
---

Point this machine's Gitstalk setup and this plugin's MCP server at the host in `$ARGUMENTS`
(for example `https://gitstalk.dev` or `http://localhost:5173`), or back to `https://gitstalk.io`
with `--reset`. With no argument, show the current host and stop.

Script: `sh "${CLAUDE_PLUGIN_ROOT}/scripts/gitstalk-setup.sh"` (on Windows without Git Bash:
`powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/gitstalk-setup.ps1"`,
same subcommands, `-Reset` for `--reset`).

1. `<script> host <url>` (or `<script> host --reset`, or `<script> host` to show). It checks that
   `<url>/api/setup` answers, saves the host in `<config>/gitstalk/host` so every later setup
   command (`detect`, `register`, `remote`, `create`, `verify`) uses it when `GITSTALK_WEB` is
   unset, and prints `mcp_url:` and a `claude_code:` line. On `cannot reach`, report it and stop.
2. Run the `claude_code:` line as printed: it saves the MCP URL in this plugin's `mcp_url`
   option (Claude Code keeps it in the user settings). If it says no installed plugin has the
   id `gitstalk@gitstalk`, find the id with `claude plugin list` and run it with that id.
3. Tell the person, in three lines at most: restart Claude Code, then run `/mcp` and sign in to
   the `gitstalk` server on the new host; if they also added a Gitstalk MCP server by hand
   (`claude mcp add`), disable one of the two in `/mcp`, because both offer the same tool
   names; git needs `/gitstalk:setup` once per host (each host has its own account and token).

Never print a token or keychain contents. Do not edit shell profiles or `settings.json` by hand.
