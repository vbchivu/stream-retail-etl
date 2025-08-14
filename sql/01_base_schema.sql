-- Base schema
CREATE TABLE
    IF NOT EXISTS sales_raw (
        event_id TEXT,
        store_id INT,
        sku INT,
        qty INT,
        ts BIGINT
    );