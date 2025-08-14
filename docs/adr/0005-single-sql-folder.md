# 0005 — Single canonical `sql/` folder at repo root

**Status:** Accepted — 2025-08-12

## Context

We had SQL files in multiple locations (root and `compose/`), causing confusion and non-deterministic init.

## Decision

Keep a **single canonical** SQL directory: `sql/` at repo root.  
Compose mounts only this folder into Postgres’ `/docker-entrypoint-initdb.d`.

## Consequences

- Deterministic DB bootstrap.
- Fewer "which file applied?" issues.

## Alternatives Considered

- Per-service SQL folders — unnecessary complexity for this project.

## Implementation Notes

- Current contents: `00_sales_raw.sql` (creates `sales_raw`).
- Future migrations use numeric prefixes (`01_…`, `02_…`) in this same folder.
