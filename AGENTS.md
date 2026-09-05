# Patchwork development

- Work in this repository. Target Swift 6+; do not build the analyzed app.
- Use SwiftSyntax for syntax facts. Do not label textual type expressions as resolved dependencies, inferred purity, or proven effects.
- Keep observations, analysis limitations, and design judgement separate. No LLM is required at runtime.
- Preserve deterministic JSON ordering and source locations. Malformed/unreadable input must fail, not produce a partial clean report.
- Compare Git snapshots without checkout/reset or executing target build scripts.
- Run `swift test` and `python3 Scripts/smoke.py .build/debug/patchwork` after analysis/CLI changes.
- Product direction and deferred ideas belong in `docs/ideas.md`; OSS references belong in `docs/references.md`.
- GitHub repository creation and publishing await the user's trial. Local Git commits are authorized.
