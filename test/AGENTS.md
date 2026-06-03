# test/ — Bats unit tests

Constraints specific to the test suite.

- Tests must be offline and deterministic. Exercise the pure helpers in `lib/`
  against fixtures and temporary files; never reach the network. Real install
  behaviour over the network is covered by `asdf plugin test`, not here.
- ShellCheck cannot parse the Bats DSL, so only `*.bash` helpers are linted;
  `*.bats` files are formatted by shfmt but not linted. Keep non-trivial logic
  in `.bash` helpers or in `lib/` where it can be linted and reused.
- Install tests use a stand-in executable rather than the real binary so they
  pass on any architecture. Use `BATS_TEST_TMPDIR` for scratch space.
- When adding OS/architecture support or changing release parsing, add or update
  the corresponding test here in the same change.
