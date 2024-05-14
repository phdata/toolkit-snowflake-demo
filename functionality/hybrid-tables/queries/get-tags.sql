USE DATABASE hybrid_table_demo;

SELECT query_tag, DATEDIFF(second, start_time, end_time) as time FROM table(information_schema.query_history()) WHERE query_tag LIKE 'benchmark%' ORDER BY start_time DESC LIMIT 20;
