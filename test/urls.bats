#!/usr/bin/env bats
#
# Release asset naming and download URL construction. The asset embeds the tag
# with its leading "v"; the installable version does not.

load test_helper

@test "asset_stem embeds the v-prefixed tag and the triple" {
  run asset_stem 0.1.0 x86_64-unknown-linux-gnu
  [ "$output" = "allowlister-v0.1.0-x86_64-unknown-linux-gnu" ]
}

@test "release_download_url points at the versioned release path" {
  run release_download_url 0.1.0 allowlister-v0.1.0-aarch64-apple-darwin.tar.gz
  [ "$output" = "https://github.com/nickderobertis/allowlister/releases/download/v0.1.0/allowlister-v0.1.0-aarch64-apple-darwin.tar.gz" ]
}

@test "tarball and checksum names share the asset stem" {
  stem="$(asset_stem 0.1.0 aarch64-unknown-linux-gnu)"
  [ "$stem.tar.gz" = "allowlister-v0.1.0-aarch64-unknown-linux-gnu.tar.gz" ]
  [ "$stem.sha256" = "allowlister-v0.1.0-aarch64-unknown-linux-gnu.sha256" ]
}
