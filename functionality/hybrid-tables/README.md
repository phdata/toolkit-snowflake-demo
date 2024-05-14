# Hybrid Tables

This repository contains scripts to create and benchmark Snowflake [hybrid tables](https://docs.snowflake.com/en/user-guide/tables-hybrid).

Snowflake hybrid tables are both a row store and a column store. The row store is used for fast inserts and point queries, while the column store will be chosen by the query planner for analytical queries.

## Requirements

* Make `brew install make`
* Flyway `brew install flyway`
* [phData Toolkit](https://toolkit.phdata.io/tool-access)

## Running the Benchmarks

Run the benchmark:

```shell
make benchmark
```

Delete the artifact database from running benchmarks:

```shell    
make clean
```
