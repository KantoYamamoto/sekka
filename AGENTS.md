# Patchwork development

- Work in this repository. Target Swift 6+; do not build the analyzed app.
- Use SwiftSyntax for syntax facts. Do not label textual type expressions as resolved dependencies, inferred purity, or proven effects.
- Keep observations, analysis limitations, and design judgement separate. No LLM is required at runtime.
- Preserve deterministic JSON ordering and source locations. Malformed/unreadable input must fail, not produce a partial clean report.
- Compare Git snapshots without checkout/reset or executing target build scripts.
- Run `swift test` and `python3 Scripts/smoke.py .build/debug/patchwork` after analysis/CLI changes.
- Product direction and deferred ideas belong in `docs/ideas.md`; OSS references belong in `docs/references.md`.
- Before implementation, read `docs/decisions/README.md` and the relevant decision records. For each substantive choice about behavior, analysis accuracy, scope, interfaces, or tradeoffs, add/update a decision record in the same change/commit. Do not defer this to a later documentation task.
- Follow `docs/decisions/TEMPLATE.md`: lead with a short Japanese "こういう場合はこうする" rule, then concretely record purpose/context, what, why, why not, how, limitations, revisit conditions, and evidence. Separate user requirements, implementation choices, and unverified hypotheses. Do not invent historical reasons or validation results.
- Keep one decision per record and link the index, implementation and relevant tests/reports. Minor implementation details can update an existing record; do not create a record for every edit. If a policy changes, preserve the old reasoning, mark it superseded, and link the replacement in both directions. Keep README usage and `docs/ideas.md` consistent.
- GitHub repository creation and publishing await the user's trial. Local Git commits are authorized.
