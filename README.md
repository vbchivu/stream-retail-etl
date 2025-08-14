# stream-retail-etl 🛒⚡

Kafka ➜ PostgreSQL streaming ETL that ingests ≥ 1M events/day and powers real-time dashboards.  
Local-first with Docker Compose; cloud-ready later.

---

## 🚀 Quick start

```bash
# 1) Clone
git clone https://github.com/vbchivu/stream-retail-etl.git
cd stream-retail-etl

# 2) Create env (edit PG creds and optional rate)
cp compose/.env.example compose/.env

# 3) Bring it up
docker compose -f compose/docker-compose.yml up --build -d
```

**Open UIs:**

- Grafana → [http://localhost:3000](http://localhost:3000) (admin / admin)
- Prometheus → [http://localhost:9090](http://localhost:9090)

First run will pull images; give it ~30–90s to settle.

---

## 📦 What you get

**Flow:** Producer (Python) → Kafka (KRaft) → Kafka Connect (JDBC Sink) → PostgreSQL → Prometheus/Grafana.

### Reality check (smoke tests)

```bash
# Connector registered and running?
curl -s http://localhost:8083/connectors | jq .
curl -s http://localhost:8083/connectors/pg-sales-jdbc-sink/status | jq .

# Rows flowing?
docker compose exec postgres   psql -U $PGUSER -d retail_ops   -c "SELECT COUNT(*) FROM sales_raw;"
```

**Expected:**

- Connector state RUNNING (worker and task)
- `sales_raw` row count increasing every few seconds

---

## 🎛 Controlling ingestion (pause / resume / rate)

Pause ingestion (stop producer only):

```bash
docker compose stop producer
```

Resume ingestion:

```bash
docker compose start producer
```

Change the event rate:  
Edit `compose/.env` → `RATE_PER_SEC=15` (try 5 or 50).

Apply:

```bash
docker compose up -d producer
```

> 💡 **Safety tip:** keep totals < ~3–5k rows/min on a small laptop unless testing limits.

---

## 📂 Project structure

```
stream-retail-etl/
├─ docker-compose.yml              # all services (root-level)
├─ .env.example                    # copy to .env; set PG creds, rate, etc.
├─ compose/
│  ├─ prometheus.yml               # Prometheus scrapes exporters
│  ├─ connect/Dockerfile           # builds Connect with JDBC plugin
│  ├─ connectors/
│  │  ├─ pg_sink.json              # JDBC Sink (sales → sales_raw)
│  │  ├─ pg_agg_sink.json          # JDBC Sink (sales_agg_minute → table)
│  │  └─ register.sh               # registers sinks at startup
│  └─ grafana/provisioning/...     # datasources, dashboards, alerts
├─ ksql/
│  └─ statements.sql               # ksqlDB transforms (profile: ksql)
├─ sql/
│  ├─ 01_sales_raw.sql             # base DDL for raw sink
│  ├─ 02_indexes.sql               # indexes for sales_raw
│  └─ 03_sales_agg_minute.sql      # Phase 3 aggregate DDL
├─ producer/
│  ├─ app.py                       # generator
│  ├─ requirements.txt
│  └─ Dockerfile
└─ docs/
   ├─ README.md
   ├─ project-guide.md
   ├─ project-roadmap.md
   ├─ journal.md
   └─ adr/
      ├─ 0001-choice-of-stack.md
      ├─ 0002-kraft-cluster-id.md
      ├─ 0003-kafka-connect-jdbc-sink.md
      └─ 0004-observability-exporters.md

```

---

## 🔌 Services & ports

| Service            | Port  | Notes                                  |
|--------------------|-------|----------------------------------------|
| Kafka (broker)     | 9092  | KRaft single-node                      |
| Kafka Connect      | 8083  | REST API; connector auto-registration  |
| PostgreSQL         | 5432  | DB `retail_ops`                        |
| Prometheus         | 9090  | Scrapes exporters                      |
| Grafana            | 3000  | Dashboards (login admin/admin)         |
| Kafka Exporter     | 9308  | Broker/topic/consumer metrics          |
| Postgres Exporter  | 9187  | DB metrics                             |

---

## ✅ Verification checklist

```bash
# All containers healthy?
docker compose -f compose/docker-compose.yml ps

# Prometheus targets UP?
open http://localhost:9090 -> Status > Targets

# Grafana reachable?
open http://localhost:3000
```

**Expect:**

- kafka-exporter, postgres-exporter, prometheus targets show UP
- Connector `pg-sales-jdbc-sink` RUNNING
- `sales_raw` row count rises over time

---

## 🛠 Troubleshooting

**A) Kafka up but Connect shows empty connectors list**  
Wait 20–40s. If still empty:

```bash
# Try registering manually
curl -s -X POST -H 'Content-Type: application/json'   --data @compose/connectors/pg_sink.json   http://localhost:8083/connectors | jq .
```

Check logs:

```bash
docker compose logs -f kafka-connect
```

**B) `sales_raw` stays at 0**

```bash
docker compose logs -f producer
curl -s http://localhost:8083/connectors/pg-sales-jdbc-sink/status | jq .
```

Verify DB creds in `compose/.env`.

**C) Port conflicts**  
Change left side of mappings in `compose/docker-compose.yml`:

```yaml
# Grafana
- "3300:3000"
```

**D) Reset everything (includes volumes — data loss):**

```bash
docker compose -f compose/docker-compose.yml down -v
docker compose -f compose/docker-compose.yml up --build -d
```

---

## 🧠 Design choices (short version)

- **Kafka KRaft (7.6):** ZooKeeper-free, simpler single-node dev.
- **Kafka Connect JDBC Sink:** zero-code persistence to Postgres; value schemas enabled.
- **PostgreSQL 16:** familiar SQL, easy local run.
- **Prometheus + Grafana:** quick health and metrics via exporters.
- **Operator controls:** pause/resume producer, adjustable rate via env.

See: `docs/journal.md` and ADRs in `docs/adr/`.

---

## 🗺 Roadmap (highlights)

- **Phase 2:** Dashboards + alerts; CI checks; ops levers ✅/⏳
- **Phase 3:** Stream processing (ksqlDB) for real-time aggregates
- **Phase 4:** Partitions, indexes, retention; optional upserts
- **Phase 5:** Load tests, alerting polish, lightweight control panel

Full plan: `docs/project-roadmap.md`.

---

## 📜 License

MIT (or your choice). Add `LICENSE` before publishing.

---

## 🙌 Credits

Built as a teaching-friendly, local-first streaming ETL you can lift to the cloud later.
