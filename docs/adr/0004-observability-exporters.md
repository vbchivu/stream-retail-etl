# 0004 — Observability via protocol exporters

**Status:** Accepted — 2025-08-12

## Decision

Use **kafka-exporter** and **postgres-exporter** with Prometheus for dev-time metrics; defer JMX wiring.

## Context

JMX agent + config in dev adds friction and jar management. Exporters provide the “90% useful” metrics quickly (consumer lag, broker/topic stats, DB health).

## Consequences

- Immediate visibility of ingestion health and lag in Prometheus/Grafana.
- JVM internals missing (OK for dev); can add JMX later if needed.

## Implementation Notes

Prometheus scrapes:

- `kafka-exporter:9308`
- `postgres-exporter:9187`
- `prometheus:9090` (self)

## Alternatives Considered

- JMX exporter — more detailed, but heavier to set up in this phase.
