# DEMO_GOLD redesign — business use case

## Background

`DEMO_GOLD.MAIN` is the analytics layer for the retail business. It is currently
made up of:

- `GOLD_SALES_FULL`: a single denormalized "one big table" that the BI team uses
  for every sales report.
- `GOLD_CUSTOMER_SNAPSHOT`, `GOLD_PRODUCT_SNAPSHOT`: dimension snapshots that are
  truncated and reloaded every run.

Both patterns are causing pain and need to be replaced with a proper dimensional
model in `DEMO_GOLD.MAIN`.

## Problems we want this model to solve

1. **Grain is unclear in the OBT.** `GOLD_SALES_FULL` has one row per
   `ORDER_LINE_ID`, but it also carries header-level columns (`ORDER_STATUS`,
   `CHANNEL`) and customer/store/product attributes denormalized into every row.
   Analysts routinely double-count header-level facts when summing across
   the table. A single source of truth at a documented grain would prevent this.

2. **No history on dimensions.** `GOLD_CUSTOMER_SNAPSHOT` and
   `GOLD_PRODUCT_SNAPSHOT` are overwritten on every refresh. The product team
   and the marketing team have both asked, in the last quarter:
   - "Which customers had which email on the day of order X?"
   - "What was the list price of SKU 1000042 when it was first sold?"
   We cannot answer either question today. The new dimensions need SCD2
   history for at least the attributes that change: customer email, customer
   address (city/state), product list price, and product category assignment.

3. **Fact rebuilds are full-table.** `GOLD_SALES_FULL` is truncated and reloaded
   every run. Even an incremental load pattern would be a win. The new fact
   table should be incremental-friendly (clear business keys, a deterministic
   surrogate, and either an effective timestamp or an order-date partitioning
   strategy).

## Source of truth

The silver layer (`DEMO_SILVER.MAIN`) is correct and trusted. The new gold
model should be built from silver, not from bronze. Available silver tables:

- `DIM_CUSTOMER` (one row per customer, current state only)
- `DIM_PRODUCT_CATEGORY`
- `DIM_PRODUCT` (one row per SKU, current state only)
- `DIM_STORE_LOCATION`
- `DIM_STORE`
- `DIM_DATE`
- `FACT_SALES` (order-line grain, joined to all the dims above)

## Target

- Target platform: Snowflake.
- Target tooling: dbt models.
- Grain for the fact: one row per `ORDER_LINE_ID`. Document the grain in the
  emitted spec's context block.
- Dimensions: `DIM_CUSTOMER`, `DIM_PRODUCT`, `DIM_STORE`, `DIM_DATE`, and
  whatever else the modeler thinks is needed (e.g. a separate
  `DIM_PRODUCT_CATEGORY` or a degenerate dim for `CHANNEL` / `ORDER_STATUS`).
- Customer and product dims must use **SCD type 2** for the attributes called
  out in problem #2. Other attributes can stay SCD type 1 if that's simpler.
- Surrogate keys for every dim (versioned for SCD2 dims).
- The new fact replaces `GOLD_SALES_FULL`. Header-level columns
  (`ORDER_STATUS`, `CHANNEL`) belong on the fact (or as degenerate dims), not
  duplicated across attribute columns.

## Out of scope for this iteration

- Anything below silver — bronze stays as-is, raw operational tables.
- Customer / store geocoding (postal code → lat/long).
- Returns analytics as a separate fact — for now, returned-order detection can
  use the existing `ORDER_STATUS` value on the line.
