-- Aggregated table (upsert target)
CREATE TABLE
    IF NOT EXISTS sales_agg_minute (
        store_id INT NOT NULL,
        window_start_ms BIGINT NOT NULL,
        window_end_ms BIGINT NOT NULL,
        total_qty BIGINT NOT NULL,
        events BIGINT NOT NULL,
        PRIMARY KEY (store_id, window_start_ms)
    );