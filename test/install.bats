#!/usr/bin/env bats
#
# Install-script behaviour: where files land, the post-install smoke test, and
# the concise failures for a missing artifact or an unsupported install type.
# A stand-in executable keeps these tests architecture-independent; the real
# binary is exercised by `asdf plugin test`.

load test_helper

setup() {
  DOWNLOAD="$BATS_TEST_TMPDIR/download"
  INSTALL="$BATS_TEST_TMPDIR/install"
  mkdir -p "$DOWNLOAD"
}

# A fake allowlister that answers --version, so install's smoke test passes
# regardless of host architecture.
fake_binary() {
  cat >"$DOWNLOAD/allowlister" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && echo "allowlister 9.9.9"
SH
  chmod +x "$DOWNLOAD/allowlister"
}

@test "install places an executable under bin/ and nothing outside install path" {
  fake_binary
  export ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=9.9.9
  export ASDF_INSTALL_PATH="$INSTALL" ASDF_DOWNLOAD_PATH="$DOWNLOAD"
  run "$PLUGIN_DIR/bin/install"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -x "$INSTALL/bin/allowlister" ]
}

@test "install fails clearly when the downloaded binary is missing" {
  export ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=9.9.9
  export ASDF_INSTALL_PATH="$INSTALL" ASDF_DOWNLOAD_PATH="$DOWNLOAD"
  run "$PLUGIN_DIR/bin/install"
  [ "$status" -ne 0 ]
  [[ "$output" == "asdf-allowlister: "* ]]
  [[ "$output" == *"download"* ]]
  [ ! -d "$INSTALL" ]
}

@test "install rejects a non-version install type" {
  fake_binary
  export ASDF_INSTALL_TYPE=ref ASDF_INSTALL_VERSION=main
  export ASDF_INSTALL_PATH="$INSTALL" ASDF_DOWNLOAD_PATH="$DOWNLOAD"
  run "$PLUGIN_DIR/bin/install"
  [ "$status" -ne 0 ]
  [[ "$output" == *"only 'version' installs are supported"* ]]
}

@test "download rejects a non-version install type without touching the network" {
  export ASDF_INSTALL_TYPE=ref ASDF_INSTALL_VERSION=main
  export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/dl"
  run "$PLUGIN_DIR/bin/download"
  [ "$status" -ne 0 ]
  [[ "$output" == *"only 'version' installs are supported"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/dl" ]
}
