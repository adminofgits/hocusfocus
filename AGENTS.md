# Agent guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing code and follow
[AI_POLICY.md](AI_POLICY.md) when preparing outside contributions.

## Tools and repository boundaries

- Use `fd`, not `find`; `jaq`, not `jq`; and `rg`, not `grep`.
- Never commit unless explicitly asked.
- Never commit directly to `main`; create a branch first.
- Do not push, tag, or publish without explicit instruction.
- Do not start, stop, or restart the app unless the user asks you to do so.
- Do not reset Accessibility, register login items, or change the keychain as a
  side effect of tests. Use injected services instead.
- Spawn subagents only when explicitly requested.

## Running tools

Use `just` for the documented workflows. `just run` never builds; `just stop`
never builds; `just start` builds then launches. Avoid the user's `.build` lock
by using an isolated SwiftPM scratch directory during concurrent app testing.

## Changes and verification

Preserve TOML compatibility and `io.bitsugar.hocusfocus` across app metadata,
signing, CLI control, and permission commands. Keep the focus spark and shared
purple palette consistent. Preserve third-party license notices.

Report changed behavior, checks run, and limitations. Keep compilation, mocked
API tests, and real macOS focus/permission checks distinct. A menu bar app that
starts is not evidence that focus follows the pointer.
