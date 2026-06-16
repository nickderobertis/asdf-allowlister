# Repository guide

This repository is an [asdf](https://asdf-vm.com) plugin that installs the
`allowlister` command from its upstream GitHub release binaries. It contains no
application source code: it is a set of shell scripts that asdf invokes, plus
their tests and tooling.

## Two standing goals on every task

The user drives product features and their request is the priority — but carry
two goals into *every* task. When either is the lowest-error path to what the
user asked, fold it into the same task without asking first; surface the rest as
follow-ups.

1. **Engineer the context for next time.** Make the next agent (and you) see
   more for less: realistic tests that exercise the real install path the way a
   user does — especially when they report a bug existing tests missed (the
   suite plus `asdf plugin test` is the only QA loop, see "Testing") — scripts
   and recipes that automate repetitive steps and shrink their output to signal,
   and terse `AGENTS.md` notes capturing what the code doesn't make obvious.
2. **Engineer the codebase and environment.** Be the engineer the user isn't:
   prioritize the technical initiatives that keep the codebase clean,
   maintainable, and repeatable, and keep environment setup automated and
   consistent (`just bootstrap` from a clean clone). Strict quality gates plus
   local/CI parity — the same `just check` on the same pinned toolchain across
   the Linux and macOS legs — make results repeatable, not "works on my
   machine." A clean base and a reproducible environment are usually how the
   user's feature ships with a low error rate.

## Stack and composition

This repo was composed from the create-repo skill's reference pieces:

- **Product shape — `shapes/asdf-plugin.md`.** The deliverable is the `bin/`
  script contract (`list-all`, `download`, `install`, `latest-stable`, `help.*`)
  that asdf invokes to list, download, and install `allowlister` release
  binaries. The version/stable/download policy, install-path safety, explicit
  platform mapping, and `asdf plugin test` integration all come from this shape.
- **Language — `languages/bash.md`.** The runtime is pure Bash held to the
  Bash 3.2 feature set for macOS portability, with `shellcheck` + `shfmt` as the
  enforced lint/format gates and `bats` for unit tests. The shape and the
  language agree that the host-tool integration (`asdf plugin test`) is the e2e
  tier; see "Testing" for the e2e and coverage decisions.
- **Cross-cutting — `ci.md` (always).** CI runs `just bootstrap` then `just
  check` on a `ubuntu-latest` + `macos-latest` matrix and proves the real
  end-user install path with `asdf-vm/actions/plugin-test`. The branch-protection
  and squash-merge model from `ci.md` is recorded under "Commits and releases".

Excluded, with reason:

- **`shapes/cli.md`** — the installed `allowlister` binary is a CLI, but it is
  *upstream's* product, not this repo's. This repo ships the asdf plugin that
  installs it, so the CLI shape does not apply here.
- **`monorepo.md`** — single plugin, single language, one deployable; there is
  no workspace of independently versioned packages to coordinate.
- **The live/integration and benchmark tiers from `ci.md`** — there is no
  credentialed external service to exercise beyond the public GitHub releases
  API (already covered by `asdf plugin test`), and shell glue is not
  performance-sensitive, so no `bench.yml`.

## Architecture

- `bin/` — the asdf plugin scripts. Each is an entry point asdf calls directly.
- `lib/utils.bash` — shared constants and functions sourced by the `bin/`
  scripts. Sourcing it has no side effects; all network access lives in
  functions the caller invokes explicitly.
- `test/` — Bats unit tests plus `test_helper.bash`.
- `justfile` — the task runner and quality gate.
- `.github/workflows/` — `ci.yml` (Linux + macOS quality and integration),
  `commitlint.yml` (Conventional Commit enforcement on PRs), `release.yml`
  (automated releases on push to `main`).

The plugin runtime is pure shell. The only Node in this repository is dev-only
tooling for release automation and commit linting (`package.json`, the lockfile,
`.releaserc.json`, `.commitlintrc.json`); it is never required to use the plugin
and the package is private (never published to npm).

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

### End-to-end (e2e) decision

The e2e tier is `just test-e2e`, which drives the plugin through asdf exactly as
a user does: `asdf plugin add` (here via `asdf plugin test`, which clones the
committed plugin tree), then a real `list-all` → `download` → `install` of an
actual release, finishing with the `allowlister --version` smoke test of the
installed binary. This *is* the plugin's bats/host-tool harness, so we treat it
as the e2e and wire it into `just check` (and CI) rather than maintaining a
second, parallel e2e suite — for an asdf plugin the host-tool install path is the
end-to-end journey. It exercises both the happy path (a successful install) and
failure handling (a failed smoke test removes the install directory; a missing
asset aborts), so e2e is a deliberate, present tier, not a silent omission.

### Coverage decision

There is no line-coverage gate, and that is a deliberate decision, not an
oversight. `bash.md` flags shell as the case most likely to justify dropping the
coverage bar: the available tools (`kcov`, `bashcov`) instrument a running shell
and are coarse, platform-fragile (`kcov` is effectively Linux-only and would
not run on the macOS leg of the matrix), and they cannot see the code that
matters most here — the `bin/` scripts only ever execute *inside* asdf, under
asdf-provided env vars, which is precisely what `asdf plugin test` covers. Rather
than chase a misleading percentage, coverage is enforced structurally: every
shared `lib/` helper has direct bats unit tests (parsing, platform mapping, URL
construction, checksum handling, install-path safety, latest-stable selection,
token handling), and the end-to-end install path is proven by `asdf plugin test`
on both Linux and macOS in CI. New `lib/` helpers must ship with their own tests;
that — not a `--fail-under` number — is the coverage bar this repo enforces.

## Git state

Commit deliberately and only when asked. `asdf plugin test` runs against
committed state, so commit before relying on it. Never commit secrets, tokens,
or large generated artifacts.

## Commits and releases

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org).
  commitlint enforces this — locally via the commit-msg hook and as a required
  PR check — so the type prefix (`feat`, `fix`, `docs`, `ci`, …) is not optional.
- Releases are automated: on push to `main`, semantic-release derives the next
  version from the commit types since the last release, creates the tag, and
  publishes a GitHub Release. `feat` yields a minor bump, `fix`/`perf` a patch,
  and a `BREAKING CHANGE:` footer a major; other types release nothing. Choose
  the commit type accordingly — it is the release control.
- Do not hand-create version tags or releases, and do not add an npm-publish
  step: tags are human-facing versioning only (asdf installs from the default
  branch). A changelog is intentionally not committed back, to avoid a bot push
  against the protected branch.

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
