# syntax=docker/dockerfile:1.7

# ── Stage 1: Backend dependencies ────────────────────────────────────────────
FROM python:3.11-slim AS backend-deps

WORKDIR /app

COPY backend/requirements.txt requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt


# ── Stage 2: Frontend dependencies ───────────────────────────────────────────
FROM node:20 AS frontend-deps

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y default-jre-headless --no-install-recommends

WORKDIR /app

COPY frontend/package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci


# ── Stage 3: Export OpenAPI spec from backend ─────────────────────────────────
FROM backend-deps AS backend-api

COPY backend/ backend/
COPY backend/.env.example .env.example

RUN PYTHONPATH=/app python backend/scripts/export_openapi.py backend/openapi.json


# ── Stage 4: Generate API client (shared by test and build) ───────────────────
FROM frontend-deps AS frontend-codegen

COPY openapitools.json ./openapitools.json
COPY --from=backend-api /app/backend/openapi.json /tmp/openapi.json
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.openapi-generator \
    npx -y @openapitools/openapi-generator-cli@2.41.0 generate \
    -i /tmp/openapi.json \
    -g typescript-axios \
    -o /generated-api \
    --additional-properties="npmName=@finance-tracker/api,supportsES6=true,withSeparateModelsAndApi=true,apiPackage=api,modelPackage=models" \
    --global-property apis,models,supportingFiles,modelDocs=false,apiDocs=false


# ── Stage 5: Build frontend ────────────────────────────────────────────────────
FROM frontend-deps AS frontend-build

COPY frontend/ .
COPY --from=frontend-codegen /generated-api ./src/api
RUN npm run build


# ── Stage 6: Backend tests ────────────────────────────────────────────────────
FROM backend-deps AS backend-test

COPY backend/ backend/
COPY backend/.env.example .env.example

WORKDIR /app/backend
ENV PYTHONPATH=/app

CMD ["pytest"]


# ── Stage 7: Frontend tests ───────────────────────────────────────────────────
FROM frontend-deps AS frontend-test

COPY frontend/ .
COPY --from=frontend-codegen /generated-api ./src/api

CMD ["npm", "run", "test:run"]


# ── Stage 8: Final runnable image ─────────────────────────────────────────────
FROM python:3.11-slim AS final

WORKDIR /app

COPY --from=backend-deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend-deps /usr/local/bin /usr/local/bin

COPY backend/ backend/
COPY backend/.env.example .env.example
COPY --from=frontend-build /app/dist/ backend/public/

WORKDIR /app/backend
ENV PYTHONPATH=/app

CMD ["sh", "-c", "mkdir -p data && alembic upgrade head && uvicorn backend.app.main:app --host 0.0.0.0 --port 8000"]
