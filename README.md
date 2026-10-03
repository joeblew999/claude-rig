# claude-rig

[![test](https://github.com/joeblew999/claude-rig/actions/workflows/test.yml/badge.svg)](https://github.com/joeblew999/claude-rig/actions/workflows/test.yml)
[![latest release](https://img.shields.io/github/v/release/joeblew999/claude-rig?include_prereleases)](https://github.com/joeblew999/claude-rig/releases/latest)

**Turn a Mac, a Linux box, a Windows PC or a fresh UTM VM into a Claude worker you give work to from your phone.** It installs your dev tools and Claude Code, brings in your own Claude config and skills from a folder or repo of yours, and keeps a Claude session running, so the machine shows up in the Claude app. Safe to re-run, and no secrets stored.

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh                  # macOS, Linux
irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1 | iex                       # Windows, in PowerShell
mise run push -- user@host                                                                                  # any machine, from your Mac
```

**Pre-release:** the always-on session has run logged in only on a Mac so far; on Windows and Linux it is tested up to the login ([Findings](docs/findings.md)). While this line is here, `mise run release:publish` marks each release a pre-release.

Then: [Getting started](docs/getting-started.md). Everything else is in [the docs](docs/README.md) ([as a site](https://joeblew999.github.io/claude-rig/)).

[MIT](LICENSE). The rig ships no Claude config or skills of its own: you bring yours ([Your config](docs/concepts/config.md)).
