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

If upstream changes the Linux libc its binaries link against, the target triple
shifts (for example `*-unknown-linux-gnu` → `*-unknown-linux-musl`). Old
releases keep only their original assets, so the flavour is selected per version
rather than hardcoded: bump `MUSL_MIN_VERSION` in `lib/utils.bash` to the first
release carrying the new assets and update the cutoff cases in
`test/platform.bats`. Confirm the boundary against the actual published
releases (the release at the cutoff must have the new assets, the one before it
the old).

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

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org):
`type(optional scope): summary`, for example `fix: handle empty release list`.
Allowed types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
`refactor`, `revert`, `style`, `test`. Keep the summary lower-case with no
trailing period.

commitlint enforces this in two places: the optional local commit-msg hook
(enabled by `pre-commit install`) and a required `commitlint` check on every PR.
Validate a branch's messages locally with:

```sh
just commitlint
```

## Releases (automated)

Releases are cut by [semantic-release](https://semantic-release.gitbook.io) when
commits land on `main`. It reads the commit types since the last release and
decides the bump:

- `feat:` → minor (e.g. 0.1.0 → 0.2.0)
- `fix:` / `perf:` → patch (e.g. 0.1.0 → 0.1.1)
- a `BREAKING CHANGE:` footer (or `type!:`) → major
- other types (`docs`, `ci`, `chore`, `refactor`, `test`, `style`, `build`) →
  no release

So **the commit type is the release control** — there is no manual version
bump, tag, or release step. Preview what would be released with
`GITHUB_TOKEN=$(gh auth token) just debug-release`. Tags are human-facing
versioning only; asdf installs the plugin from the default branch.

## Pull request checklist

- [ ] `just check` passes locally.
- [ ] Commits follow Conventional Commits (`just commitlint`), with the type
      chosen to produce the intended release bump.
- [ ] New or changed behaviour has tests (platform mapping, parsing, URLs,
      selection, install, failure paths).
- [ ] Scripts stay portable (no `sort -V`, no GNU-only flags, Bash 3.2 safe).
- [ ] Success paths emit only what asdf expects; errors are concise and go to
      stderr.
- [ ] Comments and docs are written for future readers, not as a change log.
- [ ] No secrets, tokens, or large artifacts are committed.
- [ ] Durable constraints are captured in the nearest `AGENTS.md`.
