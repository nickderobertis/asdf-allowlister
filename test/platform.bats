#!/usr/bin/env bats
#
# Host OS/architecture to release-target-triple mapping, including the
# normalisation of equivalent names and the errors for unsupported hosts.

load test_helper

@test "maps Linux x86_64 to the gnu triple" {
  run target_triple_for Linux x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64-unknown-linux-gnu" ]
}

@test "maps Linux aarch64 to the gnu triple" {
  run target_triple_for Linux aarch64
  [ "$output" = "aarch64-unknown-linux-gnu" ]
}

@test "maps macOS x86_64 to the darwin triple" {
  run target_triple_for Darwin x86_64
  [ "$output" = "x86_64-apple-darwin" ]
}

@test "maps macOS arm64 to the darwin triple" {
  run target_triple_for Darwin arm64
  [ "$output" = "aarch64-apple-darwin" ]
}

@test "normalises amd64 to x86_64" {
  run target_triple_for Linux amd64
  [ "$output" = "x86_64-unknown-linux-gnu" ]
}

@test "normalises arm64 to aarch64 on Linux" {
  run target_triple_for Linux arm64
  [ "$output" = "aarch64-unknown-linux-gnu" ]
}

@test "fails with a concise message on an unsupported OS" {
  run target_triple_for Windows x86_64
  [ "$status" -ne 0 ]
  [[ "$output" == "asdf-allowlister: unsupported OS"* ]]
  [ "${#lines[@]}" -eq 1 ]
}

@test "fails with a concise message on an unsupported architecture" {
  run target_triple_for Linux riscv64
  [ "$status" -ne 0 ]
  [[ "$output" == "asdf-allowlister: unsupported architecture"* ]]
  [ "${#lines[@]}" -eq 1 ]
}
