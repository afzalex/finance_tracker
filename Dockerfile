# ── Stage 1: Backend dependencies ────────────────────────────────────────────
FROM python:3.11-slim AS backend-deps

WORKDIR /app

COPY backend/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt


# ── Stage 2: Frontend dependencies ───────────────────────────────────────────
FROM node:20 AS frontend-deps

RUN apt-get update && apt-get install -y default-jre-headless --no-install-recommends && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY frontend/package*.json ./
RUN npm install


# ── Stage 3: Export OpenAPI spec from backend ─────────────────────────────────
FROM backend-deps AS backend-api

COPY backend/ backend/
COPY backend/.env.example .env.example

RUN PYTHONPATH=/app python backend/scripts/export_openapi.py backend/openapi.json


# ── Stage 4: Generate API client (shared by test and build) ───────────────────
FROM frontend-deps AS frontend-codegen

COPY frontend/ .

COPY --from=backend-api /app/backend/openapi.json /tmp/openapi.json
RUN npx -y @openapitools/openapi-generator-cli generate \
    -i /tmp/openapi.json \
    -g typescript-axios \
    -o ./src/api \
    --additional-properties="npmName=@finance-tracker/api,supportsES6=true,withSeparateModelsAndApi=true,apiPackage=api,modelPackage=models" \
    --global-property apis,models,supportingFiles,modelDocs=false,apiDocs=false


# ── Stage 5: Build frontend ────────────────────────────────────────────────────
FROM frontend-codegen AS frontend-build

RUN npm run build


# ── Stage 6: Backend tests ────────────────────────────────────────────────────
FROM backend-deps AS backend-test

COPY backend/ backend/
COPY backend/.env.example .env.example

WORKDIR /app/backend
ENV PYTHONPATH=/app

CMD ["pytest"]


# ── Stage 7: Frontend tests ───────────────────────────────────────────────────
FROM frontend-codegen AS frontend-test

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
