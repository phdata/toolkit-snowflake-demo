I did some benchmarking on hybrid tables using the Data Generation tool. All of this was done on an xsmall warehouse except for small batch inserts on hybrid tables, where I tried larger warehouses with no effect:

* Hybrid tables are ~30% slower to insert large batches of records
* Hybrid tables are ~30% slower when retrieving large amounts of data
* Hybrid tables are ~15% slower on a query with large joins
* Hybrid tables are ~25% slower when selecting a single record from 10k records (selecting on primary key)
* Hybrid tables are 2x faster inserting small batches of records (27/second hybrid vs 13/second columnar). There seems to be an upper limit on inserting into hybrid tables at around 29/second, no matter the number of threads or warehouse size.

Inserting 1.1M rows with large batches (200k records/batche)
* datagen-hybrid,319.958s
* datagen-standard,242.381s

Select statement with a varchar filter
* query-standard-select-large,4.674s
* query-hybrid-select-large,6.228s

Select statement joining 3 tables with a filter
* query-standard-join,6.284s
* query-hybrid-join,7.261s

Insert  ~9k records using 9 threads across 3 tables, xsmall warehouse
* datagen-hybrid-single,388.051s (27 rows/second)
* datagen-standard-single,778.900s  (13 rows/second)

Select a single record
* query-hybrid-select-small,6.078s
* query-standard-select-small,4.400s