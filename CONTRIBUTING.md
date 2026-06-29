# Contributing

This project is developed under the Orchestrated Agentic Programming (OAP) workflow.

## Ground rules
- `AGENTS.md` is the operational law. Read it before changing anything.
- Implementation work happens on **feature branches via pull request**. No direct
  commits to `main` (the initial scaffold import is the only exception).
- Behavior and its documentation change in the **same** PR.
- Tests are evidence. Report results honestly by category; never mark skipped or
  not-run tests as passed.
- Respect `NON_GOALS.md`. Anything on that list is a strategic decision, not a PR.

## Workflow
1. Pick the current work order in `docs/work-orders/`.
2. Branch from fresh `main`.
3. Implement only what the work order scopes; keep the diff reviewable.
4. Run `make lint && make test`.
5. Open a PR with the report format from `AGENTS.md` §9. Do not merge; merge is a
   reviewed decision.

## License
By contributing you agree your contributions are licensed under **AGPL-3.0-only**,
consistent with the rest of the project.
