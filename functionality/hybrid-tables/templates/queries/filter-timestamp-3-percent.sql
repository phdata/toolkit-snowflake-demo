SET USE_CACHED_RESULT = false;
USE DATABASE hybrid_table_demo;

alter session set query_tag = '{"type": "{{TYPE}}", "description": "Filter ~3% of records using TIMESTAMP column", "application": "benchmark", "session": "{{SESSION_ID}}"}';

SELECT * FROM {{TYPE}}.order_history WHERE DAY(sale_timestamp) = 1;