# Hybrid Tables

This repository contains scripts to create and demo Snowflake [dynamic tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-about).

A Snowflake dynamic table is created from a SQL statement and Snowflake will automatically update the table data when the underlying data changes.


The end-result is a dynamic table 'dynamic_denormalized' that will join several other tables and automatically update when the underlying data changes.

```shell
                                                                                  
         ┌─────────────┐ ┌─────────────┐                                          
         │             │ │             │                                          
         │   location  │ │   customer  │                                          
         │             │ │             │  ┌────────────────┐ ┌────────────┐       
         └────────▲────┘ └─────▲───────┘  │                │ │            │       
                  │            │          │  order_history │ │   product  │       
                  │            │          │                │ │            │       
             ┌────┴────────────┴─────┐    └────▲───────────┘ └────▲───────┘       
             │                       │         │                  |              
             │    dynamic_customer   │         │                  │               
             │                       │         │                  │               
             └─────────────▲─────────┘         │                  │               
                           │                   │                  │               
                           │                   │                  │               
                        ┌──┴───────────────────┴───────┬──────────┘               
                        │                              │                          
                        │      dynamic_denormalized    │                          
                        │                              │                          
                        └──────────────────────────────┘                          
```

## Requirements

* Make `brew install make`
* Flyway `brew install flyway`
* [phData Toolkit](https://toolkit.phdata.io/tool-access)

## Running the Demo

The demo will:
* Create a database
* Create several tables to back dynamic tables
* Create the dynamic tables
* Insert data using the Data Generation tool
* Query the dynamic table

Run the benchmark:

```shell
make run
```

To incrementally add data and see the dynamic table update:

```shell
make datagen-increment
make query
```

Clean up all objects created by the demo:

```shell    
make clean
```
