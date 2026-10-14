# Creating a repository

Contents: when to ask first; three ways to create; the first bean; errors.

Every way needs the **create** scope: "may create repositories in namespaces where the person
may create them". `/gitstalk:setup` asks for it and the consent page shows it ticked; a token
or MCP session from before it existed lacks it (run setup again, or reconnect with `/mcp` and
tick create).

## Ask the person first

Private is the default and needs no question when the person asked for a repository. Ask
before you:

- make it **public** (`visibility: "public"`, `--public`), or
- create it in an **organization** (any `owner` other than the person).

Never pick a name for them that they did not ask for when one is already taken (409): say so
and ask.

## Three ways

1. **MCP** (signed-in session with `create`):
   `repo_create({ name, owner?, visibility?, start?, description? })`. `owner` defaults to the
   person, `visibility` to `private`, `start` to `empty` (or a starter id). It answers
   `{ full_name, clone_url, web_url, stalk, visibility, next }`; follow `next`, then
   `git remote add origin <clone_url>` (or `git clone <clone_url>`).
2. **Setup script** (git already connected; `/gitstalk:new <name>` runs it):
   `<script> create [owner/]name [--public] [--start <id>] [--description <text>]`. It uses the
   token git already keeps for the Gitstalk host (through `git credential fill`, never printed),
   calls `POST <web>/api/repos`, prints `created: <owner>/<name> (<visibility>)` and
   `web: <url>`, then sets `origin` like `remote` (or clones it when not in a repository). On
   409 it says `exists:` and still connects the remote. The host is `GITSTALK_WEB`, else the one
   saved with `host <url>` (`/gitstalk:host`), else gitstalk.io (`https://gitstalk.dev` is staging).
3. **Push to create**: `git push https://<host>/<owner>/<name>.git` (or `origin` pointing
   there) for a name that does not exist creates it, private, when the credential has `create`
   and the namespace allows it; the `remote:` lines print its web URL. A name that was used
   before or renamed away is refused. Without `create` the push is refused with a hint to use
   `repo_create` or `<web>/new`.

## The first bean

A new repository starts empty unless a starter was chosen. Push your work as a bean, never to
`stalk`, `sprout` or `main`:

```bash
git add -A && git status --short          # nothing secret (.env, keys) staged
git commit -m "Start <name>: <one sentence on what it is>"
git push origin HEAD:refs/heads/bean/<short-name>
```

Read the `remote:` lines (and `next` from `repo_create`): they say what happens to the first
bean. From then on the normal flow applies: branch from `origin/sprout`, one intent per bean.

## Errors

| Answer | Meaning | Do |
|---|---|---|
| 201 / `created:` | Made | Connect `origin`, push the first bean |
| 409 `exists` | The name is taken (maybe by you) | If it is theirs, connect to it; otherwise ask for another name |
| 403 | No `create` scope, or not allowed in that namespace | Run setup again (new token), or ask the person to create it at `<web>/new` |
| 422 | Invalid name | Letters, digits, `.`, `_`, `-`; pick a valid one |
| 401 | The stored token is gone or expired | `/gitstalk:setup` |
