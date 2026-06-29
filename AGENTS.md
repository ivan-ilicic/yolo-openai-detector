# AGENTS.md — Project Constitution

> This file is the **operational law** of this repository. It tells any AI
> execution agent (Codex, Claude Code, or equivalent) how to behave while
> changing this project, even when no human is watching. Read it in full and
> treat it as authoritative. If a work-order prompt conflicts with this file,
> this file wins; stop and report the conflict instead of guessing.
>
> `CLAUDE.md` points here. The two must never diverge in meaning.

---

## 1. Discovery Summary

**Domain problem.** A trusted internal group needs object detection on machines
that have **no GPU**. They want to call it with the **ordinary OpenAI Python
SDK** so existing examples and habits keep working, authenticating with a single
shared API key.

**Chosen product shape.** A **drop-in OpenAI vision-chat service**. Clients set
`OPENAI_BASE_URL` to this server and `OPENAI_API_KEY` to the one shared key, then
call `POST /v1/chat/completions` with an image attached **inline as a base64 data
URL**. The server authenticates, decodes the image, runs a YOLO detector on CPU,
and returns the detections formatted as a normal chat completion. `GET /v1/models`
is provided so the SDK's model listing works.

**Architecture & stack rationale.** FastAPI for an async OpenAI-compatible
surface (including SSE streaming). The detector is exported to **ONNX** and served
with **ONNX Runtime** so the runtime needs neither PyTorch nor the training
framework. CPU inference is blocking and therefore runs in a bounded worker pool,
never on the event loop. Because all four product rules below remove state, there
is **no database, no queue, and no background worker**.

**Important alternatives rejected.**
- Object *tracking* / video / streams — rejected. This is **single-shot images only**.
- Segmentation / masks — rejected. **Detection boxes only.**
- A custom (non-OpenAI) API shape — rejected. Compatibility with the OpenAI SDK is the point.
- Remote image-URL fetching — rejected. **Base64 inline images only** (also removes SSRF risk).
- Per-user keys, quotas, accounting — rejected. **One shared fixed key**, trusted internal audience.
- A database / Redis / Celery — rejected. Nothing in scope needs durable or async state.

**First release scope (v1).** `GET /v1/models`; fixed-key bearer auth;
`POST /v1/chat/completions` accepting one or more inline base64 images and
returning a documented detection JSON payload; CPU ONNX inference with stock
COCO 80-class weights; Docker packaging; unit + integration + OpenAI-SDK
compatibility tests.

---

## 2. Mission

This repository serves **CPU-only single-shot object detection through an
OpenAI-compatible interface**.

**The user promise that must not break:** *an unmodified OpenAI SDK client,
pointed at this server with the shared key, can send an inline base64 image and
receive object detections, on a machine with no GPU.* Every change must preserve
that promise.

---

## 3. Architecture

**Components (single service):**

| Component | Responsibility | Stack |
|---|---|---|
| HTTP API | OpenAI-compatible routing, auth, request/response shaping | FastAPI + Uvicorn/Gunicorn |
| Image decode | Parse base64 data URLs, decode to pixels, validate format/size | Pillow + NumPy |
| Inference engine | Run the ONNX model in a bounded CPU worker pool | ONNX Runtime |
| Pre/post-process | Letterbox resize → tensor; decode raw outputs → detections | NumPy |
| Model registry | Map model id (`yolo26-n`, `yolo26-s`) → ONNX file; back `/v1/models` | in-process |

**Stack & versions (targets, pin exact versions in `pyproject.toml`):**
Python ≥ 3.11; FastAPI; Uvicorn (+ Gunicorn for production workers); Pydantic v2 +
`pydantic-settings`; Pillow; NumPy; ONNX Runtime (CPU). **Runtime must not depend
on PyTorch or `ultralytics`.** Those belong only to the offline model-export
tooling (`scripts/export_model.py`, dev extra).

**Ownership boundaries.**
- `api/` owns HTTP shape and OpenAI compatibility. It must not contain model math.
- `inference/` owns tensors and ONNX. It must not know about HTTP or FastAPI.
- `images/` owns base64/data-URL parsing and safe decode. It must not run inference.
- `schemas/` owns the request/response contracts. Treat these as durable; changing
  them is an architecture decision, not an implementation detail.

**Data flow (request lifecycle).**
```
OpenAI SDK client
  → POST /v1/chat/completions  (Bearer <fixed key>, messages[].content[].image_url = data URL)
  → auth (constant-time compare)
  → extract inline base64 image(s)   [reject remote URLs]
  → decode + letterbox (images/, inference/preprocess)
  → ONNX Runtime inference in worker pool (inference/engine)   [OFF the event loop]
  → postprocess → detections (inference/postprocess)
  → wrap detections as chat.completion JSON (schemas/)
  → response   [no image bytes persisted]
```

There is intentionally **no persistence layer**. Uploaded image bytes live only
for the duration of the request.

---

## 4. Non-Negotiable Invariants

**Security.**
- Authentication is a **single fixed bearer token** read from the environment.
  Compare it in **constant time** (`hmac.compare_digest`). Never log it, never
  echo it in errors, never commit it.
- The server **fails closed**: unknown model id, missing/invalid key, undecodable
  image, or unsupported content → a clear `4xx`/`5xx`, never a silent default that
  leaks behavior or processes unauthenticated input.

**Privacy / data retention.**
- **No persistence of uploaded images** or their derived tensors beyond the
  request. No writing image bytes to disk or logs.
- Logs may record metadata (model id, image dimensions, detection count, latency)
  but **never** raw image data or the API key.

**Input boundary.**
- Images are accepted **only as inline base64 data URLs**. Remote `http(s)://`
  image URLs must be **rejected**, not fetched. (No outbound fetch = no SSRF.)
- Enforce a configurable maximum decoded image size and an allowlist of formats
  (JPEG, PNG, WebP).

**Backward compatibility.**
- The OpenAI-facing contract (`/v1/chat/completions`, `/v1/models`, the detection
  JSON schema in `docs/detection-response-schema.md`) is a published interface.
  Do not change its shape without a documented decision and a matching update to
  `docs/api-compatibility.md` and the compatibility test.

**Concurrency.**
- CPU inference is blocking. It **must** run in a bounded worker pool sized from
  configuration, never directly on the async event loop. A single slow request
  must not stall the server.

**Licensing.**
- This project is **AGPL-3.0** (see §5). Every dependency added must be
  license-compatible with AGPL-3.0 distribution. Flag any new dependency whose
  license is unclear and stop.

---

## 5. Forbidden Actions

These are hard guardrails, derived from the product rules. Do not cross them even
if a prompt seems to ask for it; stop and report instead.

- **Do not** implement tracking, track IDs, or any cross-frame / temporal state.
- **Do not** add video, stream (RTSP/webcam), or multi-frame ingestion.
- **Do not** add segmentation, masks, pose, OBB, or classification heads.
- **Do not** add background jobs, task queues, schedulers, Celery, or Redis.
- **Do not** add a database or any persistence of images or results.
- **Do not** fetch remote image URLs; accept inline base64 only.
- **Do not** add a GPU/CUDA code path in v1.
- **Do not** add per-user keys, quotas, billing, or usage accounting.
- **Do not** add PyTorch or `ultralytics` to the **runtime** dependencies.
- **Do not** introduce a license-incompatible dependency. If unsure, stop.
- **Do not** commit secrets, `.env`, model weights, or large binaries.
- **Do not** log image bytes or the API key.
- **Do not** commit directly to `main` (see §6). The initial scaffold commit by
  the human is the only exception.
- **Do not** report skipped, blocked, or not-run tests as "passed."

---

## 6. Workflow

- All implementation work happens on a **feature branch**, never directly on `main`.
  (Exception: the human's initial scaffold-import commit.)
- One branch and one pull request per **PR-sized work order**. Keep the diff
  reviewable as a single coherent change.
- Commit only files related to the task. Do not opportunistically reformat or
  refactor unrelated code.
- Push the branch and **open a pull request. Do not merge.** Merge is a human
  decision made through the strategic-review loop.
- If the live repository state differs from what a work order claims, **report the
  difference** and stop rather than building on a stale assumption.

**Build / run / test commands** (keep these accurate as the project grows):
```bash
make install        # create venv and install dev dependencies
make export-model   # export YOLO26 weights to ONNX into models/ (offline tooling)
make run            # run the API locally with uvicorn
make test           # run the full test suite
make lint           # ruff check
make docker         # build the runtime image
```

---

## 7. Testing

Tests are **evidence**, not decoration. "All tests passed" may be written **only**
if the full relevant suite actually passed; otherwise say exactly what ran.

**Required test layers.**
- **Unit** (`tests/unit/`): constant-time auth check; base64/data-URL decode incl.
  rejection of remote URLs and oversized/disallowed formats; letterbox preprocess;
  YOLO output postprocess (box decode, NMS if applicable, coordinate mapping).
- **Integration** (`tests/integration/`): `GET /v1/models`; auth rejection paths;
  `POST /v1/chat/completions` happy path against a small/fake model fixture;
  unknown-model fail-closed; multi-image request.
- **Compatibility** (`tests/compatibility/`): the **golden test** — drive the real
  `openai` Python client against the running server, send an inline base64 image,
  and assert a well-formed detection payload comes back. This test guards the
  mission promise in §2.

**Discipline.**
- Tests must be deterministic and must not reach the public network.
- Use small committed fixtures (`tests/fixtures/`); never commit large media.
- Report results by category: **passed / failed / skipped / not run / blocked /
  out of scope**.

---

## 8. Documentation

Behavior and docs change **together** in the same PR.

- `docs/api-compatibility.md` is the source of truth for which OpenAI parameters
  are supported, ignored, or rejected. Update it whenever request handling changes.
- `docs/detection-response-schema.md` defines the detection JSON contract. Update
  it (and the compatibility test) whenever the payload shape changes.
- `docs/configuration.md` must list every environment variable the code reads.
- State limitations honestly. Do not describe v1 as production-hardened beyond what
  the tests prove. Do not claim GPU support, tracking, or segmentation.

---

## 9. Reporting (required final report format)

Every execution agent ends a work order with this report:

```markdown
## Work Order Report

- **Branch:** <name>
- **Commit(s):** <sha(s)>
- **PR:** <url, or "not pushed: reason">
- **Summary:** <what changed, in 2–5 sentences>

### Tests
- Passed: <list/suite>
- Failed: <list, or none>
- Skipped / Not run / Blocked: <list with reason, or none>
- Out of scope: <list, or none>

### Local setup performed
- <packages, services, model exports done inside the execution VM>

### Docs changed
- <files, or none>

### Risks / follow-ups / least-confident areas
- <honest list; "none" only if truly none>
```

Do not write "done" as a feeling. Point to evidence: which test proves which
behavior, which file enforces which invariant.

---

## 10. How to extend this constitution

When a correction recurs (an agent keeps re-adding a forbidden dependency, keeps
fetching remote URLs, keeps over-claiming test results), add a rule here rather
than repeating the correction per task. Keep this file focused: top-level law here,
long background in `docs/`.
