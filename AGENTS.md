# Repository guide

This repository is an [asdf](https://asdf-vm.com) plugin that installs the
`allowlister` command from its upstream GitHub release binaries. It contains no
application source code: it is a set of shell scripts that asdf invokes, plus
their tests and tooling.

## Architecture

- `bin/` — the asdf plugin scripts. Each is an entry point asdf calls directly.
- `lib/utils.bash` — shared constants and functions sourced by the `bin/`
  scripts. Sourcing it has no side effects; all network access lives in
  functions the caller invokes explicitly.
- `test/` — Bats unit tests plus `test_helper.bash`.
- `justfile` — the task runner and quality gate.
- `.github/workflows/ci.yml` — Linux + macOS CI.

## asdf plugin script contract

- `bin/list-all` (required) prints all installable versions on one line, space
  separated, oldest first and newest last.
- `bin/download` (required) places the verified, decompressed artifact in
  `ASDF_DOWNLOAD_PATH`. On failure it leaves nothing behind in that directory.
- `bin/install` (required) installs into `ASDF_INSTALL_PATH` and nowhere else
  (temporary files excepted, and they are cleaned up).
- `bin/latest-stable` prints exactly one stable version and accepts an optional
  series query; it exits nonzero when nothing matches.
- `bin/help.*` print human-readable help; asdf adds its own headings.
- Plugin scripts read asdf-provided variables (`ASDF_INSTALL_TYPE`,
  `ASDF_INSTALL_VERSION`, `ASDF_INSTALL_PATH`, `ASDF_DOWNLOAD_PATH`).
- Plugin scripts must never invoke `asdf` themselves, must not call
  `asdf reshim`, and must not modify shell startup files.

## Shell style and portability

- Scripts are Bash (`#!/usr/bin/env bash`) with `set -euo pipefail`. Bash is
  used deliberately for arrays and `local`; keep to the Bash 3.2 feature set so
  the same scripts run on Linux and on the Bash that ships with macOS.
- Quote every expansion. Prefer plain, obvious shell over clever constructs.
- Do not use `sort -V`; it is unavailable or inconsistent on macOS/BSD and
  busybox. Versions here are strict `MAJOR.MINOR.PATCH`, so a per-field numeric
  sort is correct and portable.
- Use safe temporary directories (`mktemp -d`) and clean them up, including on
  failure. Never write to fixed global temp paths.
- Detect the platform with `uname`; keep the OS/architecture mapping explicit
  and covered by tests. Normalise `amd64`→`x86_64` and `arm64`→`aarch64`.
- macOS lacks `sha256sum`; prefer it when present and fall back to `shasum`.

## Dependencies

Runtime dependencies are intentionally small and explicit: `bash`, `curl`,
`tar`, `jq`, and a SHA-256 utility (`sha256sum` or `shasum`). They are listed in
`bin/help.deps`. Avoid adding new dependencies or non-portable flags.

## Version, stable, and download policy

- The GitHub releases API is the source of truth for installable versions,
  because this plugin installs release binaries — a version is installable only
  if a published, non-draft release exists for it.
- Only stable releases are surfaced. Drafts, pre-releases, release candidates,
  and any tag that is not strict `MAJOR.MINOR.PATCH` are excluded from every
  flow. There is no pre-release channel.
- Release tags carry a leading `v`; installable versions do not. The mapping
  lives in `asset_stem`/`release_download_url`.
- Always download a specific version's asset over HTTPS and verify it against
  the upstream `.sha256` before use. Never install from a mutable "latest" URL.
- `GITHUB_API_TOKEN` is honoured only to raise the API rate limit and only on
  API calls; it is never required and is never sent with asset downloads (the
  CDN redirect would otherwise leak it). Never commit a token.

## Install-path safety

`bin/install` writes only under `ASDF_INSTALL_PATH`, keeps only the runtime
executable, smoke-tests it with `--version`, and removes its own directory if
that fails so a broken version is never left installed.

## Quality gate

`just check` is the gate: format check, shell lint, workflow lint, unit tests,
and `asdf plugin test`. CI runs the same checks on Linux and macOS.

- Diagnostics fail or stay silent. Warning-only checks are not part of the gate.
  If a check is not worth failing on, disable it with a documented reason rather
  than letting it warn.
- Do not mask failures with `|| true`, blanket ignores, or output redirection
  that hides the cause.

## Minimal-output policy

Every gate recipe is quiet on success and prints only actionable output on
failure (the failing check and its file/test/message). Successful runs do not
dump test logs, dependency trees, or banners. Inspection recipes (`deps`,
`debug-*`) may print freely; they are not part of the gate.

## Testing

Tests are shell-native (Bats). Keep parsing, platform mapping, URL construction,
and selection logic in small pure functions in `lib/` so they can be unit-tested
offline; cover every shared helper. Network-dependent behaviour is validated by
`asdf plugin test`, not by the unit suite. New OS/architecture support must come
with a mapping test, and changes to release parsing must update the fixtures.

## Git state

Commit deliberately and only when asked. `asdf plugin test` runs against
committed state, so commit before relying on it. Never commit secrets, tokens,
or large generated artifacts.

## Documentation and comments

Write for future maintainers, not as a narrative of how the repo came to be.
Prefer timeless explanations. Comment only the non-obvious: portability traps,
upstream release quirks, and surprising constraints — never obvious shell
syntax.

## Working with AGENTS.md files

- Encode durable design constraints in the nearest applicable `AGENTS.md`. If a
  rule should guide future contributors, it belongs here or in a narrower
  `AGENTS.md`, not only in a commit message or a one-off discussion.
- Keep `AGENTS.md` content platform-neutral and tool-agnostic: describe
  repository conventions, not the configuration of any particular editor or
  assistant.
- Keep these files minimal and high-signal. State non-obvious constraints; do
  not restate language basics or duplicate guidance that already lives in a
  broader `AGENTS.md`.
- Nested `AGENTS.md` files (`bin/`, `lib/`, `test/`) hold only constraints
  specific to their subtree.
