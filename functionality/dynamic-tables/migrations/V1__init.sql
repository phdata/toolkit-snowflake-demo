CREATE SCHEMA demo;

--  Create demo tables
CREATE WAREHOUSE IF NOT EXISTS DYNAMIC_TABLE_DEMO_WH WAREHOUSE_SIZE = 'XSMALL';


-- Create the location table
CREATE TABLE demo.location (
   id INTEGER PRIMARY KEY,
   state TEXT,
   zip_code TEXT
);

-- Create the customer table with a foreign key reference to the location table
CREATE TABLE demo.customer (
   id INTEGER PRIMARY KEY,
   first_name TEXT,
   last_name TEXT NOT NULL,
   location_id INTEGER
);

CREATE OR REPLACE TABLE demo.product (
	ID INTEGER NOT NULL,
	NAME TEXT NOT NULL,
	DESCRIPTION TEXT NOT NULL,
	CATEGORY TEXT NOT NULL,
	LAUNCH_TIMESTAMP TIMESTAMP_NTZ(9) NOT NULL,
	DISCONTINUED_TIMESTAMP TIMESTAMP_NTZ(9),
	COST NUMBER(6,2) NOT NULL,
	PRICE NUMBER(7,2),
	constraint PK_0 primary key (ID)
);

CREATE OR REPLACE TABLE demo.order_history (
	ID INTEGER NOT NULL,
	PRODUCT_ID INTEGER NOT NULL,
	CUSTOMER_ID INTEGER NOT NULL,
	SALE_TIMESTAMP TIMESTAMP_NTZ(9) NOT NULL,
	RETURN_TIMESTAMP TIMESTAMP_NTZ(9),
    constraint PK_0 primary key (ID),
	constraint FK_0 foreign key (PRODUCT_ID) references demo.PRODUCT(ID),
	constraint FK_1 foreign key (CUSTOMER_ID) references demo.CUSTOMER(ID)
);
