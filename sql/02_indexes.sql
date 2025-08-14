-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_sales_raw_ts ON sales_raw (ts);

CREATE INDEX IF NOT EXISTS idx_sales_raw_store ON sales_raw (store_id);