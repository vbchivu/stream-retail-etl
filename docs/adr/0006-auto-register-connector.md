# 0006 — Idempotent connector auto-registration

**Status:** Accepted — 2025-08-12

## Context

Manual POSTing of connector configs is error-prone and race-y with Connect startup.

## Decision

Add a lightweight **sidecar container** (using the official [`curlimages/curl`](https://hub.docker.com/r/curlimages/curl)) named `connect-register` that:

1) waits for Connect REST to be ready (TCP, then HTTP 200),
2) deletes any existing connector with the same name (ignore errors),
3) POSTs our `pg_sink.json`.

## Consequences

- Deterministic, idempotent setup on `docker compose up`.
- Clear logs showing when registration happens.

## Alternatives Considered

- Install jq/scripts inside the Connect image — larger image, slower rebuilds.
- Register from host scripts — less portable in CI.

## Implementation Notes

Shell outline:

```sh
# wait for port then REST
while ! (exec 3<>/dev/tcp/connect/8083); do sleep 1; done
exec 3>&- 3<&-
until curl -fsS http://connect:8083/connectors >/dev/null; do sleep 2; done
```

### Idempotent registration

```sh
curl -fsS -X DELETE <http://connect:8083/connectors/pg-sales-jdbc-sink> || true
```

```sh
curl -fsS -X POST -H "Content-Type: application/json" \
     --data @/connectors/pg_sink.json \
     <http://connect:8083/connectors>
```
