SET USE_CACHED_RESULT = false;
USE DATABASE hybrid_table_demo;

alter session set query_tag = '{"type": "{{TYPE}}", "description": "3 table join with 1000 rows limit", "application": "benchmark", "session": "{{SESSION_ID}}"}';

SELECT * FROM {{TYPE}}.order_history o JOIN {{TYPE}}.customer c ON o.CUSTOMER_ID = c.ID JOIN {{TYPE}}.product p ON o.PRODUCT_ID = p.ID limit 1000;
