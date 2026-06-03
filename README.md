# asdf-allowlister

[![CI](https://github.com/nickderobertis/asdf-allowlister/actions/workflows/ci.yml/badge.svg)](https://github.com/nickderobertis/asdf-allowlister/actions/workflows/ci.yml)

An [asdf](https://asdf-vm.com) plugin for [**allowlister**](https://github.com/nickderobertis/allowlister) —
a structural allow/deny/defer engine for AI coding-agent shell commands.

The plugin installs the prebuilt `allowlister` release binaries published by the
upstream project and exposes the `allowlister` command as an asdf shim.

## Supported platforms

| OS | Architectures |
| --- | --- |
| Linux | `x86_64` (amd64), `aarch64` (arm64) |
| macOS | `x86_64` (Intel), `arm64` (Apple Silicon) |

Windows is **not supported**: asdf does not target it and the plugin installs
only the Linux and macOS release artifacts.

## Dependencies

The plugin shells out to a small, explicit set of tools, all standard on a
typical developer machine: `bash`, `curl`, `tar`, `jq`, and a SHA-256 utility
(`sha256sum` on Linux, `shasum` on macOS). There is nothing to build — releases
are prebuilt binaries.

## Install

Add the plugin by URL:

```sh
asdf plugin add allowlister https://github.com/nickderobertis/asdf-allowlister
```

### Latest version

```sh
asdf install allowlister latest
asdf set allowlister latest
```

### A specific version

```sh
asdf list all allowlister
asdf install allowlister 0.1.0
asdf set allowlister 0.1.0
```

### Verify

```sh
allowlister --version
```

## Version policy

Only stable releases are installable. Drafts, pre-releases, release candidates,
and any tag that is not a strict `MAJOR.MINOR.PATCH` are excluded from both
`asdf list all` and `latest`. There is no pre-release channel.

## GitHub API token (optional)

Listing versions calls the public GitHub releases API. If you hit the anonymous
rate limit, export a token to raise it:

```sh
export GITHUB_API_TOKEN=<your token>   # any token with public read access
```

The token is never required for normal use, and it is never sent when
downloading release binaries (only when listing versions). See
[`.env.example`](.env.example).

## Troubleshooting

- **Unsupported platform** — `unsupported OS …` / `unsupported architecture …`
  means upstream publishes no binary for your host. Only Linux and macOS on
  `x86_64`/`aarch64` are supported.
- **Upstream rate limiting** — `could not fetch releases from GitHub` usually
  means the anonymous API rate limit was hit. Set `GITHUB_API_TOKEN` (above) and
  retry.
- **Checksum mismatch** — `checksum verification failed` means the download did
  not match the upstream `.sha256`. It is most often a truncated or corrupted
  download; clear any proxy cache and retry. Nothing is installed in this case.
- **Build dependencies** — none. This plugin installs prebuilt binaries and runs
  no compiler. If you see a missing-tool error, install the dependency named in
  the message (for example `jq`).
- **Command not found / stale shim** — after installing or switching versions,
  ensure asdf is on your `PATH` and run `asdf reshim allowlister`. Confirm the
  active version with `asdf current allowlister`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow. In short:

1. Install [asdf](https://asdf-vm.com).
2. From the repo root, install the pinned dev tools (this adds the required
   asdf plugins for you):

   ```sh
   just bootstrap
   ```

   `just bootstrap` runs `asdf install` (which includes Node, used by the
   release and commit-lint tooling) and then `npm ci`. If you prefer to do it by
   hand, `asdf plugin add` each tool in `.tool-versions`, run `asdf install`,
   then `npm ci`.
3. Optionally `direnv allow` to auto-load a local `.env` (see `.envrc`).
4. Run the full quality gate:

   ```sh
   just check
   ```

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org)
(enforced by commitlint), and releases are cut automatically by semantic-release
when commits land on `main`. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Daily development

```sh
just format        # format shell scripts
just lint          # shellcheck
just test          # unit tests (Bats)
just plugin-test   # asdf plugin test against the committed tree
just check         # the full gate: format-check, lint, actionlint, test, plugin-test
```

### Permissions allowlist

The repository ships a conservative tool allowlist under `.claude/` for agentic
development environments. It permits the `just` recipes above plus a few narrow
direct commands (the dev tools, scoped `git` state commands, read-only
inspection). It contains no broad shell rules and no deny list. Prefer running
work through `just` recipes so the allowlist stays small.
