# Sekka development

- Work in this repository. Target Swift 6+; do not build the analyzed app.
- Read `ROADMAP.md` for current position, next task and milestone gates. When starting/completing a planned task, update its status and evidence links plus the current/next summary in the same change. Keep functionality completion separate from validation of user benefit; do not execute conditional milestones before their gates are met.
- Use SwiftSyntax for syntax facts. Do not label textual type expressions as resolved dependencies, inferred purity, or proven effects.
- Keep observations, analysis limitations, and design judgement separate. No LLM is required at runtime.
- Preserve deterministic JSON ordering and source locations. Malformed/unreadable input must fail, not produce a partial clean report.
- Compare Git snapshots without checkout/reset or executing target build scripts.
- Run `swift test` and `python3 Scripts/smoke.py .build/debug/sekka` after analysis/CLI changes.
- Product direction and deferred ideas belong in `docs/ideas.md`; OSS references belong in `docs/references.md`.
- Before implementation, read `docs/decisions/README.md` and the relevant decision records. For each substantive choice about behavior, analysis accuracy, scope, interfaces, or tradeoffs, add/update a decision record in the same change/commit. Do not defer this to a later documentation task.
- Follow `docs/decisions/TEMPLATE.md`: lead with a short Japanese "こういう場合はこうする" rule, then concretely record purpose/context, what, why, why not, how, limitations, revisit conditions, and evidence. Separate user requirements, implementation choices, and unverified hypotheses. Do not invent historical reasons or validation results.
- Keep one decision per record and link the index, implementation and relevant tests/reports. Minor implementation details can update an existing record; do not create a record for every edit. If a policy changes, preserve the old reasoning, mark it superseded, and link the replacement in both directions. Keep README usage and `docs/ideas.md` consistent.
- The user authorized a public GitHub repository and selected Sekka on 2026-09-06. Local Git commits are authorized. Keep private app source and raw review outputs out of Git.

- For each substantive Swift implementation commit, run `Scripts/self_review.py` against its parent with a saved pre-change evaluator and the current binary. Read the generated ordinary diff as well as Sekka output, record actionable observations in `docs/validation/`, and update ROADMAP. Self-review is not independent M2 validation; do not restructure input code merely to make it visible to Sekka. See `docs/validation/protocol.md`.
- Track work in GitHub issues and small pull requests using gh. Link purpose, acceptance criteria, decisions and validation. Do not push implementation commits directly to main. After passing checks and ordinary-diff self-review, routine scoped PRs may be merged to continue; clearly record that review was by the implementing agent, not independent approval. Escalate conceptual/scope decisions to the user.
- There are no current external users; backward compatibility is not required. Prefer a simpler useful contract over compatibility adapters, but document contract changes and keep analysis limitations truthful.
- After opening/updating a PR, inspect its GitHub Actions run and job summary/artifact when presentation changes. Do not merge a PR with required verification still running or failing. PR-built Sekka is self-evaluation, not independent approval.
