# shellcheck shell=bash
#
# Shared helpers for the asdf-allowlister plugin scripts.
#
# Sourced by bin/list-all, bin/latest-stable, bin/download and bin/install.
# Sourcing this file has no side effects: it only defines constants and
# functions. All network access happens inside functions the caller invokes
# explicitly, never at source time.
#
# Bash is required because these helpers use arrays and `local`. The features
# used stay within the Bash 3.2 baseline that ships on macOS so a single set of
# scripts runs unmodified on both Linux and macOS.

# The managed command and the upstream project that publishes its binaries.
TOOL_NAME="allowlister"
GH_OWNER="nickderobertis"
GH_REPO_NAME="allowlister"
GH_REPO="https://github.com/${GH_OWNER}/${GH_REPO_NAME}"
GH_API="https://api.github.com/repos/${GH_OWNER}/${GH_REPO_NAME}"

# Print a concise, actionable error to stderr and exit nonzero.
fail() {
  printf 'asdf-%s: %s\n' "$TOOL_NAME" "$*" >&2
  exit 1
}

# Resolve the GitHub API token from two candidate values, preferring the first.
# GITHUB_API_TOKEN takes precedence; GITHUB_TOKEN (commonly provided by CI and
# local tooling) is honoured as a fallback. Pure: reads only its arguments and
# prints the effective token, which may be empty.
resolve_github_token() {
  printf '%s' "${1:-${2:-}}"
}

# curl against the GitHub REST API.
#
# A token is used only when available, purely to raise the anonymous rate limit;
# it is never required for public use. The token is attached here and only here.
# Release-asset downloads (download_file) deliberately omit it: the assets are
# public and GitHub redirects them to a separate CDN host, where a forwarded
# Authorization header would both be useless and risk leaking the token to a
# third party.
gh_api_curl() {
  local token
  token=$(resolve_github_token "${GITHUB_API_TOKEN:-}" "${GITHUB_TOKEN:-}")
  if [ -n "$token" ]; then
    curl --fail --silent --show-error --location --retry 3 --retry-delay 1 \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: token ${token}" "$@"
  else
    curl --fail --silent --show-error --location --retry 3 --retry-delay 1 \
      -H "Accept: application/vnd.github+json" "$@"
  fi
}

# Download a public URL to a destination path. No credentials are sent, so the
# header is not forwarded when GitHub redirects to its asset CDN.
#   download_file <url> <dest>
download_file() {
  local url=$1 dest=$2
  curl --fail --silent --show-error --location --retry 3 --retry-delay 1 \
    -o "$dest" "$url"
}

# Extract installable stable versions from a GitHub releases API JSON array.
#
# Pure I/O boundary: reads the JSON on stdin and writes versions on stdout, so
# the version/pre-release policy is unit-tested against fixtures with no network.
# A version is installable only if a published, non-draft, non-pre-release
# exists for it (this plugin installs prebuilt release binaries), and only when
# the tag is a strict MAJOR.MINOR.PATCH after stripping a leading "v".
# Pre-releases and release candidates are excluded from every flow by design;
# see README "Version policy".
filter_release_versions() {
  jq -r '
    .[]
    | select(.draft == false and .prerelease == false)
    | .tag_name
    | ltrimstr("v")
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
  '
}

# Print every installable stable version, one per line, in upstream order.
# The GitHub releases API is the source of truth; pages are followed until a
# short page indicates the end.
list_all_versions() {
  local page=1 body count
  while :; do
    body=$(gh_api_curl "${GH_API}/releases?per_page=100&page=${page}") ||
      fail "could not fetch releases from GitHub (set GITHUB_API_TOKEN if you are being rate limited)"
    count=$(printf '%s' "$body" | jq 'length')
    [ "$count" -gt 0 ] || break
    printf '%s' "$body" | filter_release_versions
    # A short final page means there are no further releases to fetch.
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done
}

# Pick the newest version matching an optional query prefix from an ascending,
# newline-separated list read on stdin. Pure; empty output means no match.
# The query matches a whole version or a major / major.minor series, so "0.1"
# selects 0.1.x but not 0.10.x.
latest_matching() {
  local query=$1 latest="" version
  while IFS= read -r version; do
    [ -n "$version" ] || continue
    if [ -n "$query" ]; then
      case "$version" in
        "$query" | "$query".*) ;; # within the requested series
        *) continue ;;
      esac
    fi
    latest=$version # ascending input, so the last kept line is the newest
  done
  printf '%s' "$latest"
}

# Sort dotted MAJOR.MINOR.PATCH versions ascending (oldest first, newest last).
#
# `sort -V` is intentionally avoided: it is absent or behaves differently on
# macOS/BSD and busybox. list_all_versions yields only strict numeric semver, so
# a per-field numeric sort is correct, portable and simpler than the alternatives.
sort_versions() {
  LC_ALL=C sort -t. -k1,1n -k2,2n -k3,3n
}

# Map a host (uname -s, uname -m) to allowlister's release target triple.
#
# Kept pure (arguments in, string out, no `uname` call) so every supported and
# unsupported combination is covered by unit tests. Upstream publishes:
#   {x86_64,aarch64}-unknown-linux-gnu, {x86_64,aarch64}-apple-darwin,
#   x86_64-pc-windows-msvc.
# Windows is not reachable through asdf and is intentionally unsupported.
target_triple_for() {
  local kernel=$1 machine=$2 os arch
  case "$kernel" in
    Linux) os="unknown-linux-gnu" ;;
    Darwin) os="apple-darwin" ;;
    *) fail "unsupported OS '${kernel}': allowlister ships binaries for Linux and macOS only" ;;
  esac
  case "$machine" in
    x86_64 | amd64) arch="x86_64" ;;
    aarch64 | arm64) arch="aarch64" ;;
    *) fail "unsupported architecture '${machine}': allowlister ships x86_64 and aarch64 binaries only" ;;
  esac
  printf '%s-%s' "$arch" "$os"
}

# Target triple for the current host.
get_target_triple() {
  target_triple_for "$(uname -s)" "$(uname -m)"
}

# Common asset stem for a version/triple. The release asset embeds the tag with
# its leading "v"; the installable version does not. So version 0.1.0 maps to
# tag v0.1.0 and stem allowlister-v0.1.0-<triple>.
asset_stem() {
  local version=$1 triple=$2
  printf 'allowlister-v%s-%s' "$version" "$triple"
}

# Public download URL for a release asset file name.
#   release_download_url <version> <filename>
release_download_url() {
  local version=$1 filename=$2
  printf '%s/releases/download/v%s/%s' "$GH_REPO" "$version" "$filename"
}

# Verify <file> in <dir> against a sibling sha256sum-format file (also in <dir>).
# Quiet on success; on mismatch the checker's output is surfaced and the script
# exits nonzero. Linux ships sha256sum (coreutils); macOS ships shasum.
#   verify_checksum <dir> <checksum_file_name>
verify_checksum() {
  local dir=$1 checksum_file=$2 out
  if command -v sha256sum >/dev/null 2>&1; then
    out=$(cd "$dir" && sha256sum --check "$checksum_file" 2>&1) ||
      {
        printf '%s\n' "$out" >&2
        return 1
      }
  elif command -v shasum >/dev/null 2>&1; then
    out=$(cd "$dir" && shasum --algorithm 256 --check "$checksum_file" 2>&1) ||
      {
        printf '%s\n' "$out" >&2
        return 1
      }
  else
    fail "no SHA-256 utility found (need 'sha256sum' or 'shasum')"
  fi
}
