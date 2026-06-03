# bin/ — asdf plugin scripts

Constraints specific to the scripts in this directory.

- Each file is an entry point asdf executes directly. Its stdout is a contract:
  print only what asdf expects (versions, a single version, help text) and keep
  successful runs otherwise silent. Diagnostics go to stderr via `fail`.
- Resolve the plugin root and load shared code with the same prologue every
  script uses: `plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)`
  then source `lib/utils.bash`. Errors carry the `asdf-allowlister:` prefix.
- Only `version` installs are supported; reject other `ASDF_INSTALL_TYPE`
  values up front, before any network access.
- The `help.*` names end in dotted suffixes that are not shell extensions, so a
  directory-walking formatter or linter will skip them. Tooling must list these
  scripts explicitly (see the globs in the justfile).
