#!/usr/bin/env bats
#
# Checksum verification: silent on a match, nonzero and informative on a
# mismatch, using whichever SHA-256 utility the host provides.

load test_helper

@test "verify_checksum succeeds and is silent for a matching file" {
  dir="$BATS_TEST_TMPDIR"
  printf 'payload\n' >"$dir/payload.bin"
  make_checksum "$dir" payload.bin
  run verify_checksum "$dir" payload.bin.sha256
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "verify_checksum fails when the file does not match" {
  dir="$BATS_TEST_TMPDIR"
  printf 'payload\n' >"$dir/payload.bin"
  make_checksum "$dir" payload.bin
  printf 'tampered\n' >"$dir/payload.bin"
  run verify_checksum "$dir" payload.bin.sha256
  [ "$status" -ne 0 ]
  [ -n "$output" ]
}
