# asdf-allowlister task runner.
#
# Policy: every recipe is quiet on success and prints only actionable output on
# failure. `just check` runs the full quality gate. Run `just` with no arguments
# to list recipes.

# Strict bash for every recipe so failures abort and propagate through pipes.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Suppress command echoing; recipes speak only when something is wrong.
set quiet := true

# Shell scripts ShellCheck analyses. Bats files use a DSL ShellCheck cannot
# parse, so they are excluded here. The help.* scripts are listed via a glob
# because their dotted suffixes are not shell extensions and would be skipped by
# a directory walk.
lint_files := "bin/list-all bin/latest-stable bin/download bin/install bin/help.* lib/*.bash test/*.bash"

# Files shfmt formats: the lint set plus the bats tests (shfmt understands bats).
fmt_files := lint_files + " test/*.bats"

# Plugin name and the command used to validate an install.
plugin := "allowlister"
test_command := "allowlister --version"

# List available recipes.
default:
    just --list

# Install the dev tools pinned in .tool-versions (adds missing asdf plugins
# first), then the Node dev dependencies used for releases and commit linting.
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v asdf >/dev/null || { echo "asdf is required: https://asdf-vm.com" >&2; exit 1; }
    installed="$(asdf plugin list)"
    while read -r tool _rest; do
      [ -n "$tool" ] || continue
      printf '%s\n' "$installed" | grep -qx "$tool" || asdf plugin add "$tool"
    done <.tool-versions
    asdf install
    npm ci

# Format shell scripts in place (style comes from .editorconfig).
format:
    shfmt --write {{ fmt_files }}

# Fail if any shell script is not formatted; prints the offending diff.
format-check:
    shfmt --diff {{ fmt_files }}

# Lint shell scripts.
lint:
    shellcheck {{ lint_files }}

# Apply the only safe automated fix (formatting). ShellCheck has no autofixer.
lint-fix:
    shfmt --write {{ fmt_files }}

# Lint GitHub Actions workflows.
actionlint:
    actionlint

# Lint Conventional Commit messages on this branch (commits not yet on main).
commitlint:
    npx --no-install commitlint --from main --to HEAD

# Run the unit suite; quiet on success, full TAP on failure.
test:
    out="$(bats --formatter tap test/ 2>&1)" || { printf '%s\n' "$out" >&2; exit 1; }

# Integration test through asdf against the committed plugin tree. Cloning a
# local path tests the current branch's committed HEAD, so commit before running.
plugin-test:
    #!/usr/bin/env bash
    set -euo pipefail
    # A previous failed run can leave the temporary test plugin registered.
    if asdf plugin list 2>/dev/null | grep -qx "asdf-test-{{ plugin }}"; then
      asdf plugin remove "asdf-test-{{ plugin }}"
    fi
    out="$(asdf plugin test {{ plugin }} "$PWD" "{{ test_command }}" 2>&1)" || { printf '%s\n' "$out" >&2; exit 1; }

# Full quality gate.
check: format-check lint actionlint test plugin-test

# Remove transient formatter backup files.
clean:
    find . -name '*.orig' -type f -delete

# Inspection: resolved dev tool versions.
deps:
    asdf current

# Inspection: target triple resolved for this host.
debug-platform:
    bash -c 'source lib/utils.bash && get_target_triple && echo'

# Inspection: installable versions as asdf sees them (hits the network).
debug-versions:
    bin/list-all

# Inspection: what semantic-release would release (creates nothing). Needs a
# token, e.g. `GITHUB_TOKEN=$(gh auth token) just debug-release`.
debug-release:
    npx --no-install semantic-release --dry-run --no-ci
