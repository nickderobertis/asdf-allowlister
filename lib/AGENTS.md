# lib/ — shared shell helpers

Constraints specific to the shared library.

- Sourcing this code must have no side effects: define constants and functions
  only. Never perform I/O or network calls at source time.
- Keep parsing, mapping, URL construction, and selection as pure functions
  (arguments or stdin in, stdout out) so they are unit-testable offline. Isolate
  network and filesystem effects in their own small functions.
- The library is sourced, not executed, so it begins with a
  `# shellcheck shell=bash` directive instead of a shebang.
- The GitHub API token is attached in `gh_api_curl` and nowhere else. Asset
  downloads (`download_file`) must not send it: GitHub redirects assets to a CDN
  host, where the header would leak the token and serve no purpose.
