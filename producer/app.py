import os, json, time, random, uuid
from confluent_kafka import Producer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
RATE = float(os.getenv("RATE_PER_SEC", 15))
TOPIC = "sales"
p = Producer({"bootstrap.servers": BOOTSTRAP})
sleep_s = 1.0 / max(RATE, 0.001)

# Kafka Connect JSON with schema (so JDBC Sink can infer types)
EVENT_SCHEMA = {
    "type": "struct",
    "name": "sales_event",
    "optional": False,
    "fields": [
        {"field": "event_id", "type": "string", "optional": False},
        {"field": "store_id", "type": "int32", "optional": False},
        {"field": "sku", "type": "int32", "optional": False},
        {"field": "qty", "type": "int32", "optional": False},
        {"field": "ts", "type": "int64", "optional": False},
    ],
}


def build_payload():
    return {
        "event_id": str(uuid.uuid4()),
        "store_id": random.randint(1, 250),
        "sku": random.randint(1000, 9999),
        "qty": random.randint(1, 5),
        "ts": int(time.time() * 1000),
    }


while True:
    envelope = {"schema": EVENT_SCHEMA, "payload": build_payload()}
    p.produce(TOPIC, json.dumps(envelope).encode("utf-8"))
    p.poll(0)
    time.sleep(sleep_s)
