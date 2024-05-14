USE DATABASE hybrid_table_demo;

SELECT try_parse_json(query_tag)                      ['description']::string || ' (' || try_parse_json(query_tag)['type']::string || ')', query_type,
       DATEDIFF(millisecond, start_time, end_time) as execution_time,
       start_time
FROM table(information_schema.query_history())
WHERE try_parse_json(query_tag)['session']::string = '{{SESSION_ID}}'
ORDER BY try_parse_json(query_tag) ['description']::string DESC;