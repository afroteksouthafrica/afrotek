# syntax=docker/dockerfile:1
FROM public.ecr.aws/docker/library/python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps (add gcc if we later need to compile wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# App
COPY app ./app

EXPOSE 8001
# Uvicorn in production mode
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
