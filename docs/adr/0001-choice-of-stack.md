# 0001 — Choice of Stack

**Status:** Accepted — 2025-08-12

## Context

We need a local-first streaming ETL that’s easy to run with one command, demonstrably scales to ~1–10M events/day, and can migrate to cloud with minimal change.

## Decision

- **Kafka 7.6 (KRaft)** for messaging (no ZooKeeper).
- **PostgreSQL 16** as the initial sink.
- **Kafka Connect (JDBC Sink)** for zero-code persistence.
- **Prometheus 2 + Grafana 11** for metrics & dashboards.
- **Docker Compose v3** for local orchestration.
- **GitHub Actions** for CI.

## Consequences

- Fast onboarding; single `docker compose up` runs the full pipeline.
- Minimal vendor lock-in; same images run on Kubernetes later.
- Dev setup intentionally plaintext/no-TLS; hardening deferred to cloud phase.

## Alternatives Considered

- **Redpanda** (simpler ops) — licensing concerns for long-term.
- **RabbitMQ** — lacks replay semantics needed for ETL.
- **ClickHouse** as primary sink — great analytics, but Postgres is a friendlier default for demos.

## Notes

Cloud path: Strimzi (Kafka), managed Postgres (RDS/Cloud SQL), Helm charts mirroring Compose.
