# yolo-detect-api

**CPU-only single-shot object detection, exposed through an OpenAI-compatible
vision endpoint.**

Point an unmodified OpenAI SDK client at this server, authenticate with one shared
key, send an image inline as a base64 data URL, and get object detections back —
on a machine with **no GPU**.

> **Status: scaffold / pre-implementation.** This repository currently contains the
> project constitution, architecture docs, response/contract schemas, and code
> skeletons. The endpoints are stubs until the first work orders are executed (see
> `docs/work-orders/`). It is intentionally not yet runnable end to end.

---

## What it is (and is not)

It **is** a drop-in OpenAI vision-chat surface over a YOLO detector:
`POST /v1/chat/completions` with an inline base64 image returns detections;
`GET /v1/models` lists the available detector sizes.

It is **not** a tracker, a video/stream processor, a segmenter, or a multi-tenant
gateway. See [`NON_GOALS.md`](./NON_GOALS.md) for the full list and the reasons.

---

## Quickstart (target behavior, once implemented)

```bash
# 1. Install dev environment
make install

# 2. Export a CPU detector to ONNX (offline tooling; needs the dev extra)
make export-model            # writes models/yolo26-n.onnx (and optionally -s)

# 3. Run the server
export YOLO_DETECT_API_KEY="choose-a-strong-shared-secret"
make run                     # serves on http://localhost:8000

# 4. Call it with the ordinary OpenAI Python client
python scripts/smoke_client.py path/to/image.jpg
```

Using the OpenAI SDK directly:

```python
import base64
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="choose-a-strong-shared-secret",  # the shared fixed key
)

with open("image.jpg", "rb") as f:
    data_url = "data:image/jpeg;base64," + base64.b64encode(f.read()).decode()

resp = client.chat.completions.create(
    model="yolo26-n",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "detect"},  # text is ignored in v1
            {"type": "image_url", "image_url": {"url": data_url}},
        ],
    }],
)

# The assistant message content is a JSON string of detections.
print(resp.choices[0].message.content)
```

The detection payload format is specified in
[`docs/detection-response-schema.md`](./docs/detection-response-schema.md).
Optional detector overrides (`conf`, `iou`, `classes`) are passed via the SDK's
`extra_body`; see [`docs/api-compatibility.md`](./docs/api-compatibility.md).

---

## Documentation

| Doc | Purpose |
|---|---|
| [`AGENTS.md`](./AGENTS.md) | **Project constitution** — operational law for AI agents |
| [`CLAUDE.md`](./CLAUDE.md) | Pointer to `AGENTS.md` for Claude Code |
| [`NON_GOALS.md`](./NON_GOALS.md) | Explicit non-goals and why |
| [`docs/architecture.md`](./docs/architecture.md) | Components, data flow, concurrency model |
| [`docs/api-compatibility.md`](./docs/api-compatibility.md) | OpenAI parameter support matrix |
| [`docs/detection-response-schema.md`](./docs/detection-response-schema.md) | Detection JSON contract |
| [`docs/configuration.md`](./docs/configuration.md) | Environment variable reference |
| [`docs/security.md`](./docs/security.md) | Auth, fixed-key handling, threat boundaries |
| [`docs/deployment.md`](./docs/deployment.md) | Docker / sizing / scaling |
| [`docs/testing-strategy.md`](./docs/testing-strategy.md) | Test layers and discipline |
| [`docs/work-orders/`](./docs/work-orders/) | PR-sized execution work orders |

---

## License

**AGPL-3.0-only.** See [`LICENSE`](./LICENSE).

This choice is deliberate: the default detector is Ultralytics YOLO26, whose code
and trained models are AGPL-3.0. Running such a model inside a network service
triggers AGPL's network clause, so **this entire project is AGPL-3.0** and its
complete corresponding source must be offered to users of the running service. If
you ever need to keep a derivative closed-source, you must instead obtain an
Ultralytics Enterprise License **or** swap to a permissively licensed detector
(e.g. YOLOX / RT-DETR / RF-DETR) — that is an architecture decision, not a quiet
code edit. See `docs/security.md` and `AGENTS.md` §4–§5.
