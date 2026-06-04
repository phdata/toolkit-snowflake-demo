USE DATABASE DEMO_GOLD_${DEMO_NONCE};
USE SCHEMA MAIN;

-- Anti-pattern #1: "One big table" — order-line grain rows mixed with header-level
-- columns, every dim attribute flattened in. No clear grain documented, no
-- surrogate keys, no separation of measure from attribute. Joins fan out and
-- aggregates double-count anything header-level (e.g. ORDER_STATUS).
CREATE OR REPLACE TABLE GOLD_SALES_FULL (
    ORDER_ID                NUMBER(38, 0) NOT NULL,
    ORDER_LINE_ID           NUMBER(38, 0) NOT NULL,
    ORDER_DATE              DATE          NOT NULL,
    ORDER_YEAR              NUMBER(4, 0)  NOT NULL,
    ORDER_QUARTER           NUMBER(1, 0)  NOT NULL,
    ORDER_MONTH             NUMBER(2, 0)  NOT NULL,
    ORDER_DAY_NAME          VARCHAR(10)   NOT NULL,
    ORDER_IS_WEEKEND        BOOLEAN       NOT NULL,
    ORDER_STATUS            VARCHAR(20)   NOT NULL,
    CHANNEL                 VARCHAR(10)   NOT NULL,

    CUSTOMER_ID             NUMBER(38, 0) NOT NULL,
    CUSTOMER_FIRST_NAME     VARCHAR(50)   NOT NULL,
    CUSTOMER_LAST_NAME      VARCHAR(50)   NOT NULL,
    CUSTOMER_EMAIL          VARCHAR(100),
    CUSTOMER_GENDER         VARCHAR(10),
    CUSTOMER_BIRTH_YEAR     NUMBER(4, 0),
    CUSTOMER_CITY           VARCHAR(50),
    CUSTOMER_STATE          VARCHAR(50),
    CUSTOMER_SIGNUP_DATE    DATE          NOT NULL,

    SKU                     NUMBER(38, 0) NOT NULL,
    PRODUCT_NAME            VARCHAR(100)  NOT NULL,
    PRODUCT_LIST_PRICE      NUMBER(10, 2) NOT NULL,
    PRODUCT_IS_ACTIVE       BOOLEAN       NOT NULL,
    CATEGORY_ID             NUMBER(38, 0) NOT NULL,
    CATEGORY_NAME           VARCHAR(50)   NOT NULL,

    STORE_CODE              NUMBER(38, 0) NOT NULL,
    STORE_NAME              VARCHAR(100)  NOT NULL,
    STORE_OPEN_DATE         DATE          NOT NULL,
    STORE_CITY              VARCHAR(50)   NOT NULL,
    STORE_STATE             VARCHAR(50)   NOT NULL,
    STORE_COUNTRY           VARCHAR(50)   NOT NULL,
    STORE_POSTAL_CODE       VARCHAR(10),

    QUANTITY                NUMBER(3, 0)  NOT NULL,
    UNIT_PRICE              NUMBER(10, 2) NOT NULL,
    DISCOUNT_PCT            NUMBER(5, 2),
    GROSS_AMOUNT            NUMBER(12, 2) NOT NULL,
    NET_AMOUNT              NUMBER(12, 2) NOT NULL
);

-- Anti-pattern #2: Snapshot tables that get TRUNCATEd + reloaded every run.
-- Every prior value is lost. There is no SCD2 history, no effective dating,
-- no surrogate key versioning. Any downstream report that needed
-- point-in-time customer or product state is silently broken.
CREATE OR REPLACE TABLE GOLD_CUSTOMER_SNAPSHOT (
    CUSTOMER_ID             NUMBER(38, 0) NOT NULL,
    FIRST_NAME              VARCHAR(50)   NOT NULL,
    LAST_NAME               VARCHAR(50)   NOT NULL,
    EMAIL                   VARCHAR(100),
    GENDER                  VARCHAR(10),
    CITY                    VARCHAR(50),
    STATE                   VARCHAR(50),
    SIGNUP_DATE             DATE          NOT NULL,
    SNAPSHOT_LOADED_AT      TIMESTAMP_NTZ NOT NULL
);

CREATE OR REPLACE TABLE GOLD_PRODUCT_SNAPSHOT (
    SKU                     NUMBER(38, 0) NOT NULL,
    PRODUCT_NAME            VARCHAR(100)  NOT NULL,
    CATEGORY_NAME           VARCHAR(50)   NOT NULL,
    LIST_PRICE              NUMBER(10, 2) NOT NULL,
    IS_ACTIVE               BOOLEAN       NOT NULL,
    SNAPSHOT_LOADED_AT      TIMESTAMP_NTZ NOT NULL
);
