# Actions and deploys on Gitstalk

Contents: when workflows run; a deploy workflow; secrets; the push, wait, read, fix loop;
re-run, dispatch, cancel; automations; permissions and scopes; without MCP.

## When workflows run

Gitstalk runs GitHub Actions workflows from `.github/workflows/*.yml` as written for GitHub
(GitHub's parser; `actions/checkout` works unchanged). The file that runs is the copy on the
stalk.

| Trigger | On Gitstalk |
|---|---|
| `push` to `main` (or `stalk`, or the base branch) | A bean reached the stalk: it landed on the sprout and the sprout validated. `branches: [main]` works |
| `workflow_dispatch` | `actions_dispatch` or the Run button on the web, with typed inputs |
| `schedule` | Cron in UTC, at least 5 minutes apart |
| `pull_request`, `merge_group` | Not yet (`actions_workflow_list` shows them in `unsupported_events`) |

So "deploy on push to main" means: deploy each time one of your beans reaches the stalk. Your
bean's own pre-land check is `checks.toml`, not the workflow.

## A deploy workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm ci && npm run build
      - run: npx wrangler deploy
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ vars.CLOUDFLARE_ACCOUNT_ID }}
```

## Secrets

1. `actions_secret_list(repo)`: the names the repository (and its organization) has, never
   values. If the workflow needs one that is missing, **ask the person to add it** in Settings →
   Secrets and variables (the answer's `settings_url`). This is the preferred path: the value
   never passes through you.
2. Only if the person gives you the value in the chat and asks you to store it:
   `actions_secret_set(repo, name, value)`. It is write-only and audited (the log names the
   person and your client). Never invent a value, take one from a file or an environment
   variable on your own, echo it, write it to a file or commit it.
3. Plain configuration (account id, region, URL) is a variable: `actions_variable_set`, read as
   `${{ vars.NAME }}`. Never put a credential in a variable: anyone with a role reads it.
4. Runs of the stalk (push), `workflow_dispatch` and `schedule` get the secrets they name. A
   pre-land run of a bean pushed by an agent gets none.

## The loop: push, wait, read, fix

1. Push the bean that adds or changes the workflow (or code it builds), as always:
   `git push origin HEAD:refs/heads/bean/<name>`.
2. Out of other work: `actions_wait_for_run(repo, bean: "<name>")`. It holds until the bean
   reaches the stalk and the push runs it started finish (default 600 s, at most 1800; call it
   again if `outcome` is `running`). Never `sleep` to poll.
3. `outcome: completed`: each run's `conclusion`; for a failure, `failures[]` names the job, the
   failing step and the last log lines. `actions_job_log(repo, run, job?, tail?, grep?)` reads
   more (secrets are already `***`).
4. Fix the cause in a new bean, push, wait again. `bean_not_on_stalk`: the bean is red, in
   conflict or not yet validated (`bean_status`). `no_run`: no workflow fired; check
   `actions_workflow_list` (triggers, branch and path filters, problems).

`repo_status(repo).stalk_runs` answers "what happened to the last landing" at a glance;
`actions_run_list(repo, bean | workflow | status)` and `actions_run_get(repo, run)` give the rest
(jobs, steps, durations, the beans that triggered it, `run_url` for the person).

## Re-run, dispatch, cancel

- `actions_rerun(repo, run)`: the whole run again (same commit, event, inputs). Use it after the
  person fixed a secret or variable. A code fix is a new bean, not a re-run.
- `actions_dispatch(repo, workflow, inputs?)`: a workflow with `workflow_dispatch`, on the stalk.
- `actions_cancel(repo, run)`. Then `actions_wait_for_run(repo, run)` for any of them.

## Automations

`.gitstalk/automations/*.yml` are agents that run on Gitstalk events. `automation_list`,
`automation_get(repo, automation)` (file, triggers, recent runs) and `automation_run` (run now).
Their runs are Actions runs: wait and read logs with the same tools.

## Permissions and scopes

Reads need the read role. Dispatch, re-run, cancel and `automation_run` need the **maintain**
role (or owner) and the session's `write` scope; secret and variable changes need maintain and
the `secrets` scope, which the person ticks on the consent page (never ticked for them).
`repository_access(repository).may` says `run_workflows` and `set_secrets`. A refusal names
the missing scope: the person reconnects (`/mcp` → gitstalk → re-authenticate) and ticks it, or
does the step on the web. A repository whose `checks.toml` lists `.github/**` in
`protected_paths` refuses workflow changes from agent sessions: ask a maintainer to push it.

## Without MCP

The repository's Actions tab on the web shows the same runs and live logs; give the person the
`run_url`.
