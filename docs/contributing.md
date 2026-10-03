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

CI (`.github/workflows/test.yml`) runs the bootstrap on fresh macOS, Ubuntu x64 and ARM64, and Windows x64 and ARM64 runners, then the tests and `doctor` on each, and fails if a second run changes anything. It also pushes a rig over SSH to a Windows runner; that job's ARM64 leg runs only on `main`, because it takes about 20 minutes.

A release is a version tag on a commit whose CI passed, with notes saying where it was tested: [releases](https://github.com/joeblew999/claude-rig/releases).

## Report a bug or ask for something

Use the GitHub issue forms. An agent prints the same form with `mise x -- charter issue bug > body.md` (or `feature`, `upstream`); its first line is the `gh` command that files it. Labels come from `.github/labels.tsv` (`mise x -- charter labels` applies them to GitHub).

[The rules](rules.md) are binding.
