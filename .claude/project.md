# Finance Tracker Project Context

## Introduction
The Finance Tracker is a self-hosted software service that ingests finance-related Gmail messages and consolidates them into a local SQLite ledger for search, export, and analytics.

## Core Capabilities
- **Email Ingestion:** Interacts with the Gmail API via OAuth2 to fetch transaction alerts, statements, and investment notices.
- **Classification & Parsing:** Uses regex-based rules to classify emails and extract mandatory fields (amount, direction, provider, account_id).
- **Ledger Storage:** Stores all parsed transactions in a unified SQLite database (`finance.db` or `ledger.sqlite3`).
- **REST API:** A FastAPI service exposes the ledger data for a frontend application to visualize cash flow, categorization, and anomalies.
- **Frontend App:** A companion application that displays analytics, statements, and recurring trends.

## Environments
- **Local Dev:** Python Virtual Environment (`venv`), SQLite, local Docker for specific services.
- **Production/Docker:** Run via `docker-compose up --build`, leveraging Docker containers for the frontend and backend.
