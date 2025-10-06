# ./docs/RUNBOOK.md
# RUNBOOK — Local Execution (Dockerized Postgres)

## Prereqs
- Docker + Docker Compose installed.

## First-time setup
```bash
cp .env.example .env
docker compose up -d db
docker compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/00_run_all.psql


