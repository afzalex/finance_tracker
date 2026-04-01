# System Architecture

The project consists of multiple modules, with a primary focus on migrating toward a modernized backend and unified frontend architecture.

## 1. Modern Backend (`/backend/`)
The modernized Python backend architecture.
- **Framework:** FastAPI for the API server.
- **Database Logic:** SQLAlchemy ORM with Alembic for migrations.
- **CLI Ingestion:** A standalone CLI tool (`cli.py`) handles continuous or one-off email ingestion workflows (`auth`, `ingest`, `poll`).
- **Structure:**
  - `app/`: API layer (routers, models, schemas, services).
  - `ingestion/`: Ingestion logic (gmail client, parsers, classifier.py, pipeline.py).

## 2. Legacy Backend (`/finance-tracker-legacy/`)
The older, DB-driven iteration of the project.
- **Framework:** CLI-driven logic via Python scripts (`app/main.py`).
- **Difference:** Relies extensively on database-backed rules (`classifications` and `parsers` tables) without falling back to hardcoded code-level extraction rules.

## 3. Frontend (`/frontend/`)
- Single-page application logic served via an Nginx container.
- Represents the user interface for consuming the backend's FastAPI output.

## Request Flow (New Architecture)
1. **Gmail → DB:** The backend `ingestion` module fetches emails from Gmail and saves transaction entities to SQLite (`./data/finance.db`).
2. **DB → Interface:** The backend `app` module exposes the `GET /api/v1/...` REST API endpoints, connected to the same SQLite data store.
3. **Frontend:** Reacts to the API data, displaying graphs and ledgers.
