# 0003 — Kafka Connect JDBC Sink to Postgres

**Status:** Accepted — 2025-08-12

## Context

We want zero-code persistence of Kafka events into Postgres. Early failures showed the connector needs **value schemas** when `pk.mode=none`.

## Decision

- Use **cp-kafka-connect:7.6.0** with the **JDBC Sink** plugin installed at build time.
- **Converters**: key JSON (schemaless), **value JSON with schemas enabled**.
- Keep simple inserts for now; upsert is a later phase.

Connect env (excerpt):

```yaml
CONNECT_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
CONNECT_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
CONNECT_KEY_CONVERTER_SCHEMAS_ENABLE: "false"
CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE: "true"
CONNECT_CONFIG_PROVIDERS: env
CONNECT_CONFIG_PROVIDERS_ENV_CLASS: org.apache.kafka.common.config.provider.EnvVarConfigProvider
```

### Connector config (essentials)

```json
{
    "name": "pg-sales-jdbc-sink",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "topics": "sales",
        "connection.url": "jdbc:postgresql://postgres:5432/retail_ops",
        "connection.user": "${env:CONNECT_SINK_POSTGRES_USER}",
        "connection.password": "${env:CONNECT_SINK_POSTGRES_PASSWORD}",
        "insert.mode": "insert",
        "auto.create": "true",
        "auto.evolve": "true",
        "pk.mode": "none",
        "value.converter.schemas.enable": "true"
    }
}
```

## Consequences

- Avoids the HashMap value and null schema runtime error.
- Schema drift handled in dev via `auto.evolve`; can be tightened later.

## Alternatives Considered

- Custom consumer app — more flexibility, more code.
- Upsert with `pk.mode=record_key` — planned once keys are meaningful.

## Risks / Trade-offs

- `auto.create`/`auto.evolve` can hide schema issues; mitigated by Phase 4 hardening.
