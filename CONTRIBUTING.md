# Contributing

This repository holds only the Gitstalk plugin for Claude Code and Codex (skill, commands, MCP
configuration and setup scripts). Gitstalk itself, its MCP server, the web app that serves
`/setup.sh` and `/setup.ps1`, the design docs and the public docs live in
[coop-collective/gitstalk](https://github.com/coop-collective/gitstalk); its `AGENTS.md` is the
instruction set for coding agents and applies here too.

- Bugs and feature requests: open an issue in
  [coop-collective/gitstalk](https://github.com/coop-collective/gitstalk/issues) (plugin-only issues are
  welcome here as well).
- Pull requests: keep them small, one intent each. Run `claude plugin validate .` and
  `sh test/setup-tests.sh` before opening one; CI runs the tests on Linux and macOS.
- A change to `scripts/gitstalk-setup.*` usually needs the same change in the service's copy
  (`packages/web/src/setup/scripts/` in coop-collective/gitstalk), which is what
  `https://gitstalk.io/setup.sh` serves.
- A change to the server behaviour the skill describes lands in coop-collective/gitstalk first;
  update `skills/gitstalk/`, `AGENTS-snippet.md` and the README's status table when it is live.
- Bump `version` in `.claude-plugin/plugin.json` when a change should reach installed plugins.
- Never commit secrets, tokens or account ids.

Contributions are accepted under the repository's licence, [FSL-1.1-ALv2](LICENSE.md).
