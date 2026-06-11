-- Anti-pattern: "snapshot" dim tables that are TRUNCATEd and reloaded every run.
-- After this script runs there is no trace of prior customer or product values:
-- email changes, name changes, list-price changes, category renames — all lost.
-- This is the load pattern `agent model-data`'s ScdPlanner is designed to replace
-- with proper SCD2 (effective_from / effective_to + surrogate version key).

USE DATABASE DEMO_GOLD_${DEMO_NONCE};
USE SCHEMA MAIN;

TRUNCATE TABLE GOLD_CUSTOMER_SNAPSHOT;
INSERT INTO GOLD_CUSTOMER_SNAPSHOT (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, GENDER,
    CITY, STATE, SIGNUP_DATE, SNAPSHOT_LOADED_AT
)
SELECT
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    GENDER,
    CITY,
    STATE,
    SIGNUP_DATE,
    CURRENT_TIMESTAMP() AS SNAPSHOT_LOADED_AT
FROM DEMO_SILVER_${DEMO_NONCE}.MAIN.DIM_CUSTOMER;

TRUNCATE TABLE GOLD_PRODUCT_SNAPSHOT;
INSERT INTO GOLD_PRODUCT_SNAPSHOT (
    SKU, PRODUCT_NAME, CATEGORY_NAME, LIST_PRICE, IS_ACTIVE, SNAPSHOT_LOADED_AT
)
SELECT
    p.SKU,
    p.PRODUCT_NAME,
    pc.CATEGORY_NAME,
    p.LIST_PRICE,
    p.IS_ACTIVE,
    CURRENT_TIMESTAMP() AS SNAPSHOT_LOADED_AT
FROM DEMO_SILVER_${DEMO_NONCE}.MAIN.DIM_PRODUCT p
JOIN DEMO_SILVER_${DEMO_NONCE}.MAIN.DIM_PRODUCT_CATEGORY pc
    ON p.CATEGORY_KEY = pc.CATEGORY_KEY;
