# 📓 Project Journal — **stream-retail-etl**

_Last updated: 12 Aug 2025_

---

## 0. Elevator Pitch

> **Goal:** Ingest ≥ 1 million retail events per day, land them in PostgreSQL within 5 s P95 latency, and expose real-time dashboards—all runnable via `docker compose up` yet cloud-ready.

---

## 1. Architecture at a Glance

```
flowchart LR
  %% === Ingest ===
  subgraph Ingest
    P[Producer<br/>(Python)];
  end

  K[Kafka 7.6 (KRaft)];

  %% === Observability ===
  subgraph Observability
    KE[kafka-exporter];
    PE[postgres-exporter];
    Pr[Prometheus 2];
    G[Grafana 11];
  end

  %% === Edges ===
  P -->|JSON events| K;

  P -. metrics .-> Pr;
  KE --> Pr;
  PE --> Pr;
  Pr --> G;
```

Single-node dev cluster; swap Compose for Helm to scale out. Connect auto-registers the sink. Exporters feed Prometheus → Grafana.

---

## 2. Technology Choices & Rationale

| Layer         | Tool                       | Why we chose it                                          | Alternatives considered                                   |
|---------------|---------------------------|----------------------------------------------------------|-----------------------------------------------------------|
| Messaging     | Kafka (KRaft mode)         | Widely adopted, built-in replay, ZooKeeper-free ops      | RabbitMQ (no replay); Redpanda (licensing concerns)       |
| Database      | PostgreSQL 16              | Familiar SQL, JSONB, easy local run                      | ClickHouse (faster analytics, less SQL depth)             |
| ETL           | Kafka-Connect JDBC Sink    | No code, idempotent, incremental batching                | Custom consumer (flexible but more code)                  |
| Dashboards    | Grafana 11                 | Pluggable sources, instant Prometheus support            | Metabase (simpler SQL viz)                                |
| Metrics       | Prometheus 2 + exporters   | Simple, standard metrics; no JMX wrangling in dev         | JMX exporter (heavier wiring)                             |
| Orchestration | Docker Compose v3          | 1-file dev UX across OSes                                | Minikube (heavier), Podman                                |
| CI/CD         | GitHub Actions             | Free minutes, easy secrets, matrix builds                | CircleCI, Jenkins                                         |
| Docs          | Markdown + ADRs            | Lightweight, PR-reviewed                                 | Confluence (licence)                                      |

---

## 3. Service Configuration Details

### 3.1 Kafka (single broker, KRaft)

```yaml
environment:
  CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"   # static UUID for dev
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
  KAFKA_LOG_DIRS: "/tmp/kraft-combined-logs"
```

CLUSTER_ID & KAFKA_NODE_ID are mandatory in 7.x (no ZooKeeper).

### 3.2 PostgreSQL

- Credentials via `compose/.env` → `PGUSER`, `PGPASSWORD`, `POSTGRES_DB=retail_ops`.
- Single canonical SQL folder: `sql/`.
- `sql/00_sales_raw.sql` creates table:

```sql
sales_raw(event_id TEXT, store_id INT, sku INT, qty INT, ts BIGINT)
```

(Phase 3+) Aggregates like `sales_agg_minute` will come from stream processing; empty/absent now is expected.

### 3.3 Kafka Connect (JDBC Sink)

- Image: `confluentinc/cp-kafka-connect:7.6.0`
- Plugin installed at build time (JDBC).
- Converters: key JSON (schemaless), value JSON with schemas enabled → avoids earlier null schema error.
- Env Config Provider to interpolate DB creds from env in `pg_sink.json`.
- Auto-registration sidecar: `connect-register` waits for REST and POSTs connector config idempotently.

### 3.4 Producer (Python)

- Publishes to `sales` topic.
- Env:  
  - `KAFKA_BOOTSTRAP_SERVERS=kafka:9092`  
  - `RATE_PER_SEC` (default 15)  
- Control: Pause/Resume via `docker compose stop/start producer`.  
  Change rate → edit Compose env → `up -d --build producer`.

### 3.5 Prometheus & Exporters

- kafka-exporter (:9308) for broker/topic/consumer metrics (and lag).
- postgres-exporter (:9187) for DB metrics.
- Prometheus scrapes both and itself; Grafana reads from Prometheus.

---

## 4. Development Workflow

Clone & run:

```bash
cp compose/.env.example compose/.env   # set PGUSER/PGPASSWORD
docker compose -f compose/docker-compose.yml up -d --build
```

Verify:

```bash
curl -s http://localhost:8083/connectors/pg-sales-jdbc-sink/status | jq .
docker compose exec postgres psql -U $PGUSER -d retail_ops -c "SELECT COUNT(*) FROM sales_raw;"
```

Stop & clean:

```bash
docker compose -f compose/docker-compose.yml down -v
```

---

## 5. FAQ / Talking Points

| Question | Answer |
|----------|--------|
| Why no ZooKeeper? | Kafka 7 KRaft is GA—simpler ops, fewer processes. |
| Will this scale? | Compose is dev-only. In prod: Kubernetes (Strimzi) for Kafka; managed Postgres (RDS/Cloud SQL). |
| Is Postgres enough? | Yes for 1–10 M/day. If needed: Timescale partitions; or sink to ClickHouse/BigQuery; keep Postgres as system of record. |
| Exactly-once? | Not yet. Stretch goal uses Connect transactions + stricter DB isolation or upsert semantics with `pk.mode=record_key`. |
| Security? | Dev-only: PLAINTEXT, env-based creds, non-root containers. In cloud: TLS/SASL + Secrets Manager. |
| Where are aggregates? | Phase 3 (stream processing). `sales_agg_minute` empty/missing now is expected. |

---

## 6. Decision Records (index)

| ADR   | Title                                                           | Date       |
|-------|-----------------------------------------------------------------|------------|
| 0001  | Choice of Stack                                                  | 2025-07-21 |
| 0002  | KRaft Cluster-ID & Node-ID convention                            | 2025-07-21 |
| 0003  | Use exporters (kafka/postgres) instead of JMX in dev             | 2025-08-12 |
| 0004  | Single canonical sql/ at repo root                               | 2025-08-12 |
| 0005  | Enable value-schemas for JDBC Sink (avoid null-schema errors)    | 2025-08-12 |

_Add new ADRs under `docs/adr/` as architecture changes._

---

## 7. Next Planned Phases (roadmap)

| Phase | Focus                | Key Deliverables |
|-------|----------------------|------------------|
| 2     | Observability polish | Grafana dashboards, Prometheus alerts |
| 3     | Stream processing    | ksqlDB; sales_agg_minute/hourly; optional Postgres sink |
| 4     | Data model & perf    | Day partitions + indexes; retention; optional upsert |
| 5     | Control UI           | Web panel for producer/connector control |
| 6     | Load testing & CI    | k6 tests; CI gate for connector & data checks |
| 7     | Cloud deployment     | Helm + Strimzi; Terraform for EKS/RDS |

---

## 8. Glossary

- **KRaft** – Kafka’s Raft-based consensus (no ZooKeeper).  
- **Kafka Connect** – Pluggable data-integration runtime; we use JDBC Sink.  
- **ADR** – Architecture Decision Record; one page per key choice.  
- **P95 latency** – 95th percentile; our SLA < 5 s event-to-DB.

---

## How to use this journal

Keep it living: any behavior change should update this or add an ADR.  
When someone asks “why exporters over JMX?”, point them to ADR-0003.
