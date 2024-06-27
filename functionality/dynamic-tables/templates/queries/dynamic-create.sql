USE SCHEMA dynamic_table_demo.demo;
SET USE_CACHED_RESULT = false;

CREATE OR REPLACE DYNAMIC TABLE dynamic_customer
  TARGET_LAG = '1 minutes'
  WAREHOUSE = DYNAMIC_TABLE_DEMO_WH
  AS
SELECT
    c.ID,
    c.FIRST_NAME,
    c.LAST_NAME,
    l.STATE ,
    l.ZIP_CODE
FROM
    customer c join location l on c.location_id = l.id;

CREATE OR REPLACE DYNAMIC TABLE dynamic_denormalized
  TARGET_LAG = '1 minutes'
  WAREHOUSE = DYNAMIC_TABLE_DEMO_WH
  AS
SELECT
    c.ID AS customer_id,
    c.FIRST_NAME AS customer_first_name,
    c.LAST_NAME AS customer_last_name,
    c.STATE AS customer_state,
    c.ZIP_CODE AS customer_zip_code,
    p.ID AS product_id,
    p.NAME AS product_name,
    p.DESCRIPTION AS product_description,
    p.CATEGORY AS product_category,
    p.LAUNCH_TIMESTAMP AS product_launch_timestamp,
    p.DISCONTINUED_TIMESTAMP AS product_discontinued_timestamp,
    p.COST AS product_cost,
    p.PRICE AS product_price,
    o.ID AS order_id,
    o.SALE_TIMESTAMP AS order_sale_timestamp,
    o.RETURN_TIMESTAMP AS order_return_timestamp
FROM
    order_history o
        JOIN dynamic_customer c ON o.CUSTOMER_ID = c.ID
        JOIN product p ON o.PRODUCT_ID = p.ID;