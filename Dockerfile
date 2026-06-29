# Runtime image: serve the exported ONNX model via ONNX Runtime.
# Deliberately NO torch and NO ultralytics here — those belong to offline export.
FROM python:3.11-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# System libs needed by Pillow/onnxruntime at runtime.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install runtime deps first for layer caching.
COPY requirements.txt ./
RUN pip install -r requirements.txt

# App source.
COPY pyproject.toml ./
COPY src ./src
RUN pip install --no-deps .

# Model ONNX files are supplied at deploy time (volume mount or a separate build
# stage that runs scripts/export_model.py). They are NOT baked in here and NOT
# committed to the repo.
#   docker run -v $(pwd)/models:/app/models ...

EXPOSE 8000

# Run with gunicorn + uvicorn workers in production. Tune workers/threads per host
# (see docs/configuration.md). YOLO_DETECT_API_KEY must be provided at runtime.
CMD ["gunicorn", "yolo_detect_api.main:app", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "1", \
     "--timeout", "60"]
