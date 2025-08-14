-- 1) Define the enveloped stream (matches our producer’s JSON-with-schema)
CREATE STREAM SALES_ENVELOPED (
    schema STRUCT < ignore STRING >, -- we don't use it, but it's present
    payload STRUCT < event_id STRING,
    store_id INT,
    sku INT,
    qty INT,
    ts BIGINT >
)
WITH
    (KAFKA_TOPIC = 'sales', VALUE_FORMAT = 'JSON');

-- 2) Unwrap into a clean stream
CREATE STREAM SALES AS
SELECT
    payload - > event_id AS event_id,
    payload - > store_id AS store_id,
    payload - > sku AS sku,
    payload - > qty AS qty,
    payload - > ts AS ts
FROM
    SALES_ENVELOPED EMIT CHANGES;

-- 3) Aggregate per minute; ensure we emit window_start for JDBC PK
CREATE TABLE
    SALES_AGG_MINUTE
WITH
    (
        KAFKA_TOPIC = 'sales_agg_minute',
        VALUE_FORMAT = 'JSON'
    ) AS
SELECT
    store_id,
    WINDOWSTART AS window_start_ms,
    SUM(qty) AS total_qty
FROM
    SALES
WINDOW
    TUMBLING (SIZE 1 MINUTE)
GROUP BY
    store_id EMIT CHANGES;