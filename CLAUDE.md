# CLAUDE.md

**The operating law of this project lives in [`AGENTS.md`](./AGENTS.md). Read it
in full and obey it as authoritative.** This file exists because Claude Code loads
`CLAUDE.md` at session start; it deliberately does **not** duplicate the whole
constitution, to avoid the two files drifting apart. `AGENTS.md` is the single
source of truth. If anything here seems to conflict with `AGENTS.md`, `AGENTS.md`
wins.

Before doing anything, also skim `docs/architecture.md`,
`docs/api-compatibility.md`, and `docs/detection-response-schema.md`.

---

## The hard rules (full versions in AGENTS.md §4–§6)

This is a **CPU-only, single-shot object-detection** service exposed through an
**OpenAI-compatible** `/v1/chat/completions` vision endpoint, authenticated by one
**fixed bearer key**, licensed **AGPL-3.0**.

Never, without stopping to report:

- ❌ tracking, track IDs, temporal/cross-frame state
- ❌ video, streams, multi-frame input
- ❌ segmentation, masks, pose, OBB, classification
- ❌ background jobs, queues, schedulers, Celery, Redis
- ❌ a database or any persistence of images/results
- ❌ fetching remote image URLs (inline base64 only — this also prevents SSRF)
- ❌ a GPU/CUDA path in v1
- ❌ per-user keys, quotas, billing, accounting
- ❌ PyTorch or `ultralytics` in **runtime** dependencies (export tooling only)
- ❌ logging image bytes or the API key
- ❌ committing secrets, `.env`, model weights, or large binaries
- ❌ committing directly to `main`
- ❌ reporting skipped / not-run tests as "passed"

Always:

- ✅ compare the API key in constant time; **fail closed** on anything unexpected
- ✅ run CPU inference in a bounded worker pool, **off** the event loop
- ✅ keep `api/`, `inference/`, `images/`, `schemas/` boundaries clean
- ✅ change behavior and its docs in the **same** PR
- ✅ work on a feature branch, open a PR, **do not merge**
- ✅ end with the report format in `AGENTS.md` §9
