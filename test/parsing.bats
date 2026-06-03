#!/usr/bin/env bats
#
# Version parsing and pre-release filtering from the GitHub releases payload,
# plus the portable version sort. These run offline against a fixed payload;
# real network listing is covered by `asdf plugin test`.

load test_helper

# A representative releases API payload: stable releases, a pre-release, a
# draft, a non-semver tag, and a stable flag paired with a pre-release-looking
# tag. Only strict, published, non-pre-release MAJOR.MINOR.PATCH tags survive.
releases_fixture() {
  cat <<'JSON'
[
  { "tag_name": "v0.2.0", "draft": false, "prerelease": false },
  { "tag_name": "v1.0.0-rc.1", "draft": false, "prerelease": true },
  { "tag_name": "v0.3.0", "draft": true, "prerelease": false },
  { "tag_name": "nightly", "draft": false, "prerelease": true },
  { "tag_name": "v0.2.0-beta", "draft": false, "prerelease": false },
  { "tag_name": "v0.1.0", "draft": false, "prerelease": false }
]
JSON
}

@test "filter_release_versions keeps only stable semver releases" {
  run filter_release_versions <<<"$(releases_fixture)"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "0.2.0" ]
  [ "${lines[1]}" = "0.1.0" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "filter_release_versions excludes pre-releases" {
  run filter_release_versions <<<"$(releases_fixture)"
  [[ "$output" != *"1.0.0"* ]]
  [[ "$output" != *"rc"* ]]
}

@test "filter_release_versions excludes drafts" {
  run filter_release_versions <<<"$(releases_fixture)"
  [[ "$output" != *"0.3.0"* ]]
}

@test "filter_release_versions excludes non-semver and suffixed tags" {
  run filter_release_versions <<<"$(releases_fixture)"
  [[ "$output" != *"nightly"* ]]
  [[ "$output" != *"beta"* ]]
}

@test "sort_versions orders ascending without relying on lexical order" {
  run sort_versions <<<$'0.10.0\n0.2.0\n0.9.0\n1.0.0\n0.2.1'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "0.2.0" ]
  [ "${lines[1]}" = "0.2.1" ]
  [ "${lines[2]}" = "0.9.0" ]
  [ "${lines[3]}" = "0.10.0" ]
  [ "${lines[4]}" = "1.0.0" ]
}
