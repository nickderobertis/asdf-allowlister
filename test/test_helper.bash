# shellcheck shell=bash
#
# Common setup for the bats suite: locate the plugin root and load the shared
# library so its functions can be exercised directly. BATS_TEST_DIRNAME is the
# directory of the .bats file being run.
PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
export PLUGIN_DIR

# shellcheck source=lib/utils.bash
source "$PLUGIN_DIR/lib/utils.bash"

# Write a sha256sum-format checksum file next to <file> in <dir>, using whatever
# SHA-256 utility is available (matches verify_checksum's own preference).
make_checksum() {
  local dir=$1 file=$2
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$dir" && sha256sum "$file" >"$file.sha256")
  else
    (cd "$dir" && shasum --algorithm 256 "$file" >"$file.sha256")
  fi
}
