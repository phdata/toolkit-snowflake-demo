SET USE_CACHED_RESULT = false;
USE DATABASE hybrid_table_demo;

BEGIN;
DELETE FROM hybrid.order_history WHERE CUSTOMER_ID = 1;
DELETE FROM hybrid.customer WHERE id = 1;
COMMIT;
SELECT * FROM hybrid.order_history WHERE CUSTOMER_ID = 1;