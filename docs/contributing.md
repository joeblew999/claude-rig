---
title: This repository
nav_order: 6
has_children: true
---

# This repository: how it is built and kept

```sh
git clone https://github.com/joeblew999/claude-rig && cd claude-rig
mise install                   # nushell, shellcheck, charter
mise run lint && mise run test # what CI runs first
mise run docs:check            # the docs
```

## How CI runs

Every check CI makes is a mise task, so the same command runs on your machine. The workflow `.github/workflows/test.yml` holds no checks of its own: it checks out the repo, runs the bootstrap (it installs mise, so it cannot run under mise), puts mise on PATH, and then only calls `mise run`.

| Job | Runners | What it runs |
|---|---|---|
| `lint` | Ubuntu | `lint`, `docs:check`, `github:check`, `secrets:scan`, `push -- --help` (a task under `fnox exec` with no keychain), `ci:plugin` |
| `unix` | Ubuntu x64 and ARM64, macOS | `sh bootstrap.sh` on the bare runner with no config, then `ci:bootstrap` and `test` |
| `windows` | Windows x64 and ARM64 | `bootstrap.ps1` on the bare runner, then `ci:bootstrap`, `test` and `ci:windows-session` |
| `push-windows` | Windows x64; also ARM64 on `main`, because it takes about 20 minutes | `ci:sshd`, then `ci:push`: a push over SSH from the runner to itself |

What each task checks is in [Tasks](reference/tasks.md). The `ci:*` tasks rig the machine they run on, so they run only in CI (where `CI=true`) or with the home folder set to a throwaway one under the temp folder. To run the bootstrap checks on a Mac or a Linux box without touching your own home:

```sh
export HOME="$(mktemp -d)" MISE_TRUSTED_CONFIG_PATHS="$PWD"   # a throwaway home; trust this checkout there
sh bootstrap.sh | tee "$HOME.first-run.log"                     # what CI's first step does
mise run ci:bootstrap -- "$HOME.first-run.log"                  # the checks CI runs after it
```

`ci:windows-session`, `ci:sshd` and `ci:push` need Windows, and the last two change the machine's SSH server, so they run only in CI.

## Cut a release

A release is cut from your machine in about a minute: one command runs the checks CI runs, tags `main`, and publishes the GitHub Release. GitHub's CI then checks the tag on every OS; a failure there is fixed with a patch release.

```sh
mise run release -- vX.Y.Z --dry-run   # every check, and what it would do; changes nothing
mise run release -- vX.Y.Z             # the same checks, then tag, push and publish
mise run release -- vX.Y.Z --wait-ci   # also require GitHub's CI to have passed on HEAD
```

It refuses unless the working tree is clean, HEAD is `main` as on GitHub, the tag is new here and on GitHub, and `lint`, `test`, `docs:check`, `github:check` and `ci:bootstrap` pass here. It then pushes the tag and runs `mise run release:publish`: the GitHub Release, with the commits since the previous tag as its notes and a link to [Findings](findings.md) at that tag. While the root `README.md` has a line starting `**Pre-release:**`, the release is marked a pre-release. `.github/workflows/release.yml` only checks publishing on pull requests (a dry run) and can republish a tag by hand.

charter's own release commands are not used yet: `charter release` attaches built files from `dist/` and this repo ships none, and charter has no command that cuts the tag ([charter#39](https://github.com/joeblew999/charter/issues/39)). [Releases](https://github.com/joeblew999/claude-rig/releases).

## Report a bug or ask for something

Use the GitHub issue forms. An agent prints the same form with `mise x -- charter issue bug > body.md` (or `feature`, `upstream`); its first line is the `gh` command that files it. The forms and labels come from charter: `mise run github:setup` writes them from the charter `mise.toml` pins, keeping this repo's own bug form and extra labels, and `mise run github:check` (in CI) fails if they drift. `mise x -- charter labels` applies `.github/labels.tsv` to GitHub. charter's workflows are for an API project, so this repo keeps its own ([charter#36](https://github.com/joeblew999/charter/issues/36)).

[The rules](rules.md) are binding.
