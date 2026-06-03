#!/usr/bin/env bats
#
# Latest-stable selection from an ascending version list, including the optional
# series query and the no-match case.

load test_helper

versions() {
  printf '%s\n' 0.1.0 0.2.0 0.2.1 0.10.0 1.0.0
}

@test "selects the newest version with no query" {
  run latest_matching "" <<<"$(versions)"
  [ "$output" = "1.0.0" ]
}

@test "constrains to a major series" {
  run latest_matching 0 <<<"$(versions)"
  [ "$output" = "0.10.0" ]
}

@test "constrains to a major.minor series" {
  run latest_matching 0.2 <<<"$(versions)"
  [ "$output" = "0.2.1" ]
}

@test "0.1 does not match 0.10.x" {
  run latest_matching 0.1 <<<"$(versions)"
  [ "$output" = "0.1.0" ]
}

@test "no match yields empty output" {
  run latest_matching 9 <<<"$(versions)"
  [ -z "$output" ]
}
