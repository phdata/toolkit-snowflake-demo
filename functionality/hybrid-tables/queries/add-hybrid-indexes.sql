USE DATABASE hybrid_table_demo;

ALTER SESSION SET query_tag='benchmark-add-hybrid-indexes';

CREATE INDEX idx_customer_state (state) ON hybrid.customer;

CREATE INDEX idx_order_history_sale_timestamp (sale_timestamp) ON hybrid.order_history;