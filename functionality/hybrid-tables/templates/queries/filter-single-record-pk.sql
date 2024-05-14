SET USE_CACHED_RESULT = false;
USE DATABASE hybrid_table_demo;

alter session set query_tag = '{"type": "{{TYPE}}", "description": "Filter single record using INTEGER primary key", "application": "benchmark", "session": "{{SESSION_ID}}"}';

SELECT * FROM {{TYPE}}.customer WHERE id = 1;