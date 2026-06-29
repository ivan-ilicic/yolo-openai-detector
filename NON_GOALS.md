# Non-Goals

These are deliberately **out of scope**. They are not "later" features to be
sneaked in by a helpful agent — they are boundaries that define what this product
is. Each is also encoded as a forbidden action in `AGENTS.md` §5. Crossing one is a
stop-and-report event, not a judgment call.

| Non-goal | Why it is excluded |
|---|---|
| **Object tracking / track IDs** | Tracking needs temporal state across frames. v1 is single-shot: one image in, detections out, no state. |
| **Video / streams (RTSP, webcam, multi-frame)** | Same reason — no temporal pipeline. Input is discrete images only. |
| **Segmentation / masks / pose / OBB / classification** | Detection boxes only. Other heads enlarge the model, the response contract, and the test surface. |
| **Background jobs / queues / schedulers** | Detection is synchronous and fast on small CPU models. Nothing needs async orchestration, so no Celery/Redis. |
| **Database / persistence** | No quotas, accounting, or history are in scope, and images must not be retained. With nothing durable to store, a database is pure liability. |
| **Remote image-URL fetching** | Images arrive inline as base64 data URLs. Refusing to fetch URLs eliminates the SSRF attack surface entirely. |
| **GPU / CUDA path** | The target is GPU-less machines. A GPU path would double the build/test matrix for no v1 benefit. |
| **Per-user keys / quotas / billing / accounting** | The audience is trusted and internal. One shared fixed key is sufficient and far simpler. (This is intentionally weaker than a multi-tenant gateway; see `docs/security.md`.) |
| **PyTorch / `ultralytics` at runtime** | The runtime serves an exported ONNX model via ONNX Runtime. The heavy training stack is needed only by the offline export script. |
| **Web admin UI** | There is nothing to administer in v1 (no users, no quotas, no stored data). |
| **Custom-trained classes (v1)** | v1 ships stock COCO 80-class detection. Custom classes pull dataset and training work into scope and must be a separate, later effort — not a blocker for v1. |

If a real need for any of these appears, it is a **strategic decision**: it changes
the product shape, the constitution, and the architecture docs. It does not belong
in an execution-agent diff.
