#!/usr/bin/env bats
#
# GitHub API token resolution: GITHUB_API_TOKEN wins, GITHUB_TOKEN is the
# fallback, and the result is empty when neither is set.

load test_helper

@test "resolve_github_token prefers GITHUB_API_TOKEN" {
  run resolve_github_token "api-token" "gh-token"
  [ "$output" = "api-token" ]
}

@test "resolve_github_token falls back to GITHUB_TOKEN" {
  run resolve_github_token "" "gh-token"
  [ "$output" = "gh-token" ]
}

@test "resolve_github_token is empty when neither is set" {
  run resolve_github_token "" ""
  [ -z "$output" ]
}
