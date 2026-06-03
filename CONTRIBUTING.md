# Contributing

Thanks for improving asdf-allowlister. This guide covers the layout, the
conventions, and how to validate changes. Durable design constraints live in
[`AGENTS.md`](AGENTS.md) and the nested `AGENTS.md` files; this document is the
practical how-to.

## Repository structure

```
bin/            asdf plugin scripts (list-all, latest-stable, download, install, help.*)
lib/utils.bash  shared constants and functions sourced by the bin/ scripts
test/           Bats unit tests and test_helper.bash
justfile        task runner and quality gate
.github/        Linux + macOS CI
.tool-versions  pinned development tools (managed with asdf)
```

## Getting set up

1. Install [asdf](https://asdf-vm.com).
2. `just bootstrap` — adds any missing asdf plugins for the tools in
   `.tool-versions` and runs `asdf install`.
3. Optionally `direnv allow` (see `.envrc`) to auto-load a local `.env`.
4. Optionally enable the pre-commit hooks: install
   [pre-commit](https://pre-commit.com) and run `pre-commit install`. The hooks
   reuse the `just` recipes, so they match CI. They are not required and are not
   part of `just check`.

## Shell style

- Bash with `set -euo pipefail`. Stay within the Bash 3.2 feature set so scripts
  run on the Bash that ships with macOS as well as on Linux.
- Quote every expansion. Prefer simple shell over clever shell.
- No `sort -V` (not portable); use the numeric field sort in `lib/utils.bash`.
- Use `mktemp -d` for scratch space and clean it up, including on failure.
- Formatting is enforced by shfmt and configured in `.editorconfig`; linting is
  enforced by ShellCheck (`.shellcheckrc`). Run `just format` before committing.

## Running the checks

```sh
just format-check   # shfmt --diff
just lint           # shellcheck
just actionlint     # workflow linting
just test           # Bats unit tests (offline, deterministic)
just plugin-test    # asdf plugin test (see below)
just check          # all of the above, in order
```

`just test` is quiet on success; for live per-test output run `bats test/`
directly.

## Running `asdf plugin test`

`asdf plugin test` clones the repository and performs a real install, so it
tests **committed** state. Commit your work, then:

```sh
just plugin-test
```

The recipe clones the current branch's `HEAD`, lists versions, installs the
latest, and runs `allowlister --version`. If a previous run failed and left a
temporary `asdf-test-allowlister` plugin registered, the recipe removes it
first.

## Adding a new OS or architecture

1. Confirm upstream publishes a matching release asset and note its target
   triple (for example `x86_64-unknown-linux-musl`).
2. Extend `target_triple_for` in `lib/utils.bash` with the new `uname`
   mapping(s), normalising alternate names as the existing cases do.
3. Add cases to `test/platform.bats` for both the new mapping and any new
   unsupported combinations.
4. Run `just test`, then `just plugin-test` on the target platform if you can.

## Updating release parsing

When the upstream release scheme changes (asset names, checksum format, tag
shape):

1. Inspect a real release to confirm the new shape.
2. Update the affected helper(s): `filter_release_versions` (which tags count),
   `asset_stem`/`release_download_url` (asset names and URLs), or
   `verify_checksum` (checksum handling).
3. Update the fixtures and assertions in `test/parsing.bats` and
   `test/urls.bats` to match.
4. Run `just check`.

## Diagnostics: fail or stay silent

Checks in the quality gate must fail the build or produce no output — never
warn-only. If a particular diagnostic is not worth failing on, disable it with a
documented reason rather than letting it emit warnings. Do not mask failures
with `|| true`, blanket ignores, or output redirection that hides the cause.

## Minimal output

Gate recipes are quiet on success and print only actionable detail on failure
(the failing check and its file/test/message). Do not add recipes that dump test
logs, dependency trees, or banners on success. Inspection recipes (`just deps`,
`just debug-*`) may print freely; they are not part of the gate.

## Pull request checklist

- [ ] `just check` passes locally.
- [ ] New or changed behaviour has tests (platform mapping, parsing, URLs,
      selection, install, failure paths).
- [ ] Scripts stay portable (no `sort -V`, no GNU-only flags, Bash 3.2 safe).
- [ ] Success paths emit only what asdf expects; errors are concise and go to
      stderr.
- [ ] Comments and docs are written for future readers, not as a change log.
- [ ] No secrets, tokens, or large artifacts are committed.
- [ ] Durable constraints are captured in the nearest `AGENTS.md`.
