---
title: Secrets
nav_order: 5
parent: Concepts
---

# Secrets: names in each repo, values in the keychain

Read this before you add a secret to one of the owner's repos, run a task that needs one, or give an agent a token. It holds the rules every repo follows with fnox, the secret manager (fnox.jdx.dev), each with its reason, and what was tried, rejected or not tried yet. The same rules apply in fleet-api and the VM tool.

## The rules

| Rule | Why |
|---|---|
| **A repo's own secret is named after the repo:** its name in capitals, dashes as underscores, then what it is: `FLEET_API_ACCESS_CLIENT_ID`, `CLAUDE_RIG_…`, `UTM_VM_…` | Every repo's values sit in one place, the keychain under the service `fnox`. The prefix keeps two repos' `CLIENT_ID` apart and says whose a secret is |
| **Shared credentials keep their plain names:** `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `GITHUB_TOKEN` | Tools read those names themselves (wrangler, `gh`), and they belong to no one repo |
| **A secret keeps the name of the repo that issues it, also in the repos that use it.** A machine's fleet-api token is `FLEET_API_ACCESS_CLIENT_ID` and `FLEET_API_ACCESS_CLIENT_SECRET` in claude-rig too, not a name of its own | One name, so one place to look it up and rotate it |
| **One name everywhere:** the fnox name, the keychain item and the environment variable the code reads are the same | Nothing to look up. A name that differs from its item hides which item a task really uses |
| **Values live in the keychain; each repo's `fnox.toml` holds names only** and is committed | A `fnox.toml` with no values is safe in a public repo. A plaintext `default` is a value: never use one for a real secret |
| **Tasks get secrets through `fnox exec`** in the task's `run` line (fleet-api's `access:token`, which `push` runs) | fnox's own advice: "Put `fnox exec` in tasks that need secrets so those tasks work from a shell, an editor, or CI" ([mise integration](https://fnox.jdx.dev/guide/mise-integration)). mise's fnox env plugin is called "an incomplete experiment" on the same page |
| **A repo sees only the secrets it declares.** They go in a profile named after the repo, and the repo's `mise.toml` sets `FNOX_PROFILE` to it and `FNOX_NO_DEFAULTS=true` | fnox loads the global config under every repo's config ([configuration](https://fnox.jdx.dev/reference/configuration#file-location)), so a plain `fnox exec` hands a task every global secret. On the owner's Mac, `fnox list` in a folder with its own `fnox.toml` showed over 50 names; with the profile alone, only the folder's own |
| **Each `fnox.toml` starts with `root = true` and `env = "exec"`** | `root` stops the search at the repo. `env = "exec"` keeps the values out of an interactive shell, where an agent could read them, while `fnox exec` still gets them |
| **A secret a task can do without is `if_missing = "ignore"`** | CI runners and other people's machines have no keychain items. The task then says itself what it skips |
| **`fnox scan` runs in CI** (`mise run secrets:scan`, in the lint job) | The repo is public. It checks every file git would commit for token shapes and secret-looking assignments |
| **Agents use a token through the credential proxy, not the MCP server** | See [Agents](#how-an-agent-uses-a-token-without-seeing-it) below |

## How a task gets a secret

claude-rig's `fnox.toml` declares no secret at this commit. The one secret a rigged machine needs, its own fleet-api token, is made by fleet-api's `access:token` task, which runs under fleet-api's `fnox exec` with fleet-api's Cloudflare credentials; `push` runs that task in fleet-api's checkout and sends the result to the machine ([Reporting](reporting.md#the-machines-token)). So claude-rig's tasks see no Cloudflare credential.

```sh
fnox list                      # the names this repo declares, no values
fnox check --all               # whether each one resolves; prints no values
```

`fnox list` and `fnox check` run from the repo's folder in a shell where mise is active, so they use the claude-rig profile. Avoid `fnox get` and `fnox export`: they print values.

To add a secret to a repo, with the value typed at a hidden prompt rather than on the command line:

```sh
fnox set CLAUDE_RIG_EXAMPLE --provider keychain   # writes the name into fnox.toml's profile, the value into the keychain
```

Then add `if_missing` and a `description` to the line it wrote. `fnox remove` takes the name out of `fnox.toml` but leaves the keychain item; delete that in Keychain Access.

## How an agent uses a token without seeing it

fnox has two ways to let an agent use a secret. Only one keeps the value from the agent.

| | Credential proxy (`fnox proxy run`) | MCP server (`fnox mcp`) |
|---|---|---|
| What the agent gets | A placeholder in place of each value | Tools: `get_secret` (the value) and `exec` (runs a command with the values) |
| Where the value goes | Only into HTTPS requests that match a rule: domain, methods, paths, header | Into the command the agent chose |
| Tried on the owner's Mac, 3 Oct 2026, with a made-up value | The child saw `fnox_proxy_…`; the request to the allowed domain carried the value and the echoed value came back as the placeholder; a request to another domain was refused | With `tools = ["exec"]`, `echo $VALUE` came back `[REDACTED]`, but the value printed reversed came back in full |
| Decision | **Use it** for agents | **Do not use it** to hide a value. fnox says its `exec` "provides audit visibility … not secret isolation" ([MCP](https://fnox.jdx.dev/guide/mcp)) |

The proxy's limits, from the same trial and fnox's [proxy guide](https://fnox.jdx.dev/guide/proxy):

- **It is not a sandbox.** fnox: "A determined process running as the same user may bypass proxy environment variables … or invoke fnox directly". It keeps a value out of an agent's environment and transcript; it does not stop an agent that sets out to get it.
- **The program must honour the proxy and CA settings fnox passes.** curl does. nushell's `http` does not trust fnox's certificate and fails, so claude-rig's own tasks keep `fnox exec`.
- **`egress = "strict"`, the default, refuses every domain without a rule.** An agent's own traffic (Claude's API) needs `egress = "permissive"`, or a rule. Not tried with `claude` itself.
- **Not wired in yet:** the session does not start Claude under the proxy, and no proxy rules are committed.

## What else fnox offers, and what the fleet does with it

| Feature | Decision | Why |
|---|---|---|
| Profiles | **Used**, one per repo | The scoping rule above. Environment profiles (`-P fleet-api,production`) can stack on top later |
| "Projects" | Not a fnox feature | fnox has no projects. A project is a folder with a `fnox.toml`, merged over the global config ([hierarchical config](https://fnox.jdx.dev/guide/hierarchical-config)). Doppler, Infisical and Bitwarden Secrets Manager have projects of their own, as provider settings; the keychain has none |
| `fnox scan` | **Used** in CI; **not** in `capture` | `capture` and `push` keep their own check ([Your config](config.md#where-a-run-finds-it)): fnox scan has no detector for Anthropic keys, its secret-assignment detector flagged a skill's documentation on the owner's Mac, and CI tests `push` on Windows with nushell alone |
| Leases (short-lived credentials) | **Not tried** | fnox's Cloudflare lease makes tokens that expire (default 15 minutes, at most 24 hours) from a parent token with "API Tokens: Edit" ([Cloudflare leases](https://fnox.jdx.dev/leases/cloudflare)). It fits an agent that deploys. Trying it creates real tokens on the account, so it waits for the owner |
| `fnox sync` | Not used | It copies secrets from a remote provider into a local encrypted cache. The keychain is already local |
| The daemon | Not used | It caches slow remote providers in memory. Keychain reads are local |
| `fnox activate` (shell hook) | Not needed | With `env = "exec"` nothing enters the shell, and tasks do not depend on the shell |
| mise's fnox env plugin | Not used | fnox's docs call it incomplete and recommend `fnox exec` |

## Limits

- **Values are on the owner's Mac only.** Linux and Windows machines in the fleet have none of the owner's keychain items. A task that needs a secret runs on the Mac, or a secret is made for the machine alone, as its fleet-api token is.
- **macOS may ask once per keychain item** the first time a program reads it.
- **`fnox scan` is a heuristic.** fnox: "a clean scan does not prove that files or git history contain no secrets" ([scan](https://fnox.jdx.dev/cli/scan)). It skips what `.gitignore` ignores.
