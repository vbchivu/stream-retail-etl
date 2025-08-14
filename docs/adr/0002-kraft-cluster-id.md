# 0002 — Kafka in KRaft (single broker)

**Status:** Accepted — 2025-08-12

## Context

Kafka 7+ recommends using KRaft mode (no ZooKeeper). For single-node development, explicit IDs and simplified replication settings are required.

## Decision

Run a single broker in KRaft mode with fixed IDs and PLAINTEXT listeners.

**Key environment variables (excerpt):**

```yaml
CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"
KAFKA_NODE_ID: 1
KAFKA_BROKER_ID: 1
KAFKA_PROCESS_ROLES: broker,controller
KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
KAFKA_CONTROLLER_QUORUM_VOTERS: "1@kafka:9093"
KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
```

## Consequences

- Deterministic startup on :9092 without ZooKeeper.
- Not highly available (by design); suitable for development and CI.

## Alternatives Considered

- **Multi-broker KRaft:** Heavier resource usage, less suitable for laptops.
- **ZooKeeper mode:** Deprecated; introduces more complexity.

## Implementation Notes

- Healthcheck uses a simple TCP probe on 127.0.0.1:9092.
