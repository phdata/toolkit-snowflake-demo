SET USE_CACHED_RESULT = false;
USE DATABASE hybrid_table_demo;

alter session set query_tag = '{"type": "{{TYPE}}", "description": "Filter varchar column to ~2% of records", "application": "benchmark", "session": "{{SESSION_ID}}"}';

SELECT * FROM {{TYPE}}.customer WHERE state = 'Minnesota' LIMIT 1000;