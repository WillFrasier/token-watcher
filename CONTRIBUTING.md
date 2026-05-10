# Contributing to TokenWatcher

Thanks for helping. This document sets **expectations** so your time and mine are respected.

## Maintainer bandwidth

The maintainer(s) may only check in **occasionally**. That means:

- PRs might sit for a while; a **gentle ping** after ~2 weeks is fine.
- Large refactors without prior discussion are unlikely to be merged quickly.
- **Security issues:** please open a **private** advisory on GitHub (or email if the repo has a security policy) rather than a public issue with exploit details.

## What merges quickly

- **Bug fixes** with a short repro or before/after behavior.
- **Docs** (README, comments where the code is non-obvious).
- **Small UX** improvements that do not require redesigning the whole app.
- **Parser robustness** (bad lines, missing keys) with minimal tests if you can add them.

## Out of scope (unless discussed first)

- Rewriting the entire UI stack or architecture “for fun.”
- Adding **cloud sync**, accounts, or telemetry without a clear privacy story and explicit opt-in.
- Bundling **non-OSS** dependencies that complicate redistribution.
- Features that require **elevated privileges** (e.g. Full Disk Access) unless there is a strong justification and documentation.

## Good first issues (ideas for newcomers)

Look for issues labeled **`good first issue`** on the GitHub repo. If none exist yet, these are typical starters:

1. **Unit tests** for `UsageParser.parseJSONL` with fixture files (valid line, malformed JSON, missing `usage`, duplicate dedup keys).
2. **README** improvements: clearer build steps, FAQ, or troubleshooting for “empty project list.”
3. **CI** improvements: matrix macOS versions, `swift test` once tests exist.
4. **Accessibility** pass: VoiceOver labels on key controls.

## How to submit a PR

1. **Fork** the repository and create a branch from `main` (or the default branch).
2. Keep changes **focused** — one logical change per PR when possible.
3. Run **`swift build`** (and **`swift test`** if tests exist) locally before pushing.
4. In the PR description, explain **what** changed and **why** (user-visible behavior helps).

## Code style

Match the existing Swift style in the repo: naming, file layout, and brevity. Prefer **clear** over **clever**.

## License

By contributing, you agree your contributions are licensed under the same terms as the project (**MIT** — see `LICENSE`).
