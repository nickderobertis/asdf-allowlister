#!/usr/bin/env bats
#
# Host OS/architecture to release-target-triple mapping, including the
# normalisation of equivalent names, the version-gated Linux libc flavour, and
# the errors for unsupported hosts.

load test_helper

@test "maps Linux x86_64 to the gnu triple before the musl cutoff" {
  run target_triple_for Linux x86_64 0.5.1
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64-unknown-linux-gnu" ]
}

@test "maps Linux aarch64 to the gnu triple before the musl cutoff" {
  run target_triple_for Linux aarch64 0.5.1
  [ "$output" = "aarch64-unknown-linux-gnu" ]
}

@test "maps Linux x86_64 to the musl triple at the cutoff" {
  run target_triple_for Linux x86_64 "$MUSL_MIN_VERSION"
  [ "$output" = "x86_64-unknown-linux-musl" ]
}

@test "maps Linux aarch64 to the musl triple after the cutoff" {
  run target_triple_for Linux aarch64 9.9.9
  [ "$output" = "aarch64-unknown-linux-musl" ]
}

@test "maps macOS x86_64 to the darwin triple regardless of version" {
  run target_triple_for Darwin x86_64 0.5.1
  [ "$output" = "x86_64-apple-darwin" ]
}

@test "maps macOS arm64 to the darwin triple regardless of version" {
  run target_triple_for Darwin arm64 9.9.9
  [ "$output" = "aarch64-apple-darwin" ]
}

@test "normalises amd64 to x86_64" {
  run target_triple_for Linux amd64 0.5.1
  [ "$output" = "x86_64-unknown-linux-gnu" ]
}

@test "normalises arm64 to aarch64 on Linux" {
  run target_triple_for Linux arm64 0.5.1
  [ "$output" = "aarch64-unknown-linux-gnu" ]
}

@test "fails with a concise message on an unsupported OS" {
  run target_triple_for Windows x86_64 0.5.1
  [ "$status" -ne 0 ]
  [[ "$output" == "asdf-allowlister: unsupported OS"* ]]
  [ "${#lines[@]}" -eq 1 ]
}

@test "fails with a concise message on an unsupported architecture" {
  run target_triple_for Linux riscv64 0.5.1
  [ "$status" -ne 0 ]
  [[ "$output" == "asdf-allowlister: unsupported architecture"* ]]
  [ "${#lines[@]}" -eq 1 ]
}

@test "linux_libc_for_version returns gnu before the cutoff and musl at/after" {
  run linux_libc_for_version 0.5.1
  [ "$output" = "gnu" ]
  run linux_libc_for_version "$MUSL_MIN_VERSION"
  [ "$output" = "musl" ]
  run linux_libc_for_version 1.0.0
  [ "$output" = "musl" ]
}

@test "version_ge compares strict semver field by field" {
  run version_ge 0.5.2 0.5.2
  [ "$status" -eq 0 ]
  run version_ge 0.5.3 0.5.2
  [ "$status" -eq 0 ]
  run version_ge 0.5.1 0.5.2
  [ "$status" -ne 0 ]
  # Field-wise, not lexical: 0.10.0 is newer than 0.9.0.
  run version_ge 0.10.0 0.9.0
  [ "$status" -eq 0 ]
  # A higher patch does not outweigh a lower minor.
  run version_ge 0.4.9 0.5.0
  [ "$status" -ne 0 ]
}
