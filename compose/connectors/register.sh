#!/usr/bin/env sh
set -e

echo "[register] Waiting for Kafka Connect REST on localhost:8083 ..."
until curl -fsS http://localhost:8083/connectors >/dev/null 2>&1; do
     sleep 2
done

echo "[register] Registering raw JDBC sink ..."
curl -fsS -X DELETE http://localhost:8083/connectors/pg-sales-jdbc-sink || true
curl -fsS -X POST -H "Content-Type: application/json" \
     --data @/connectors/pg_sink.json \
     http://localhost:8083/connectors

# Register aggregate sink only when explicitly enabled (ksql profile / env)
if [ "${CONNECT_REGISTER_AGG:-false}" = "true" ]; then
     echo "[register] Registering aggregate JDBC sink ..."
     curl -fsS -X DELETE http://localhost:8083/connectors/pg-agg-jdbc-sink || true
     curl -fsS -X POST -H "Content-Type: application/json" \
          --data @/connectors/pg_agg_sink.json \
          http://localhost:8083/connectors
else
     echo "[register] Skipping aggregate JDBC sink (CONNECT_REGISTER_AGG=false)"
fi

echo "[register] Done."
