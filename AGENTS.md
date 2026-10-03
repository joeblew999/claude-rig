# For agents

Everything about this repo is in [docs/](docs/README.md), the same pages people read. Nothing is kept here, so there is one source of truth. The same index for machines: https://joeblew999.github.io/claude-rig/llms.txt

Read, in this order:

1. [docs/README.md](docs/README.md): what is what, and the index of every page.
2. [docs/rules.md](docs/rules.md): the working rules, including how work is split between a lead and helpers. They are binding.
3. What is open: [the plan issues](https://github.com/joeblew999/claude-rig/issues?q=is%3Aopen+label%3Aplan), and the order of all the work in [charter#44](https://github.com/joeblew999/charter/issues/44).
4. The page for the part you are changing, from the index.
5. [docs/writing.md](docs/writing.md) before you write or change a page in `docs/`.

When you learn or change something, write it in the page in `docs/` it belongs to, and run `mise run docs:check`. Don't add README files elsewhere.
