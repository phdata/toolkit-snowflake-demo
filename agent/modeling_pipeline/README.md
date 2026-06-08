# Agent pipeline demo

A self-contained Snowflake demo for the Toolkit agent stack —
`ds history`, `ds lineage`, `agent discovery-build`, `agent model-data`,
`agent discovery`, and `agent pipeline-build`.

It provisions a fresh three-layer warehouse (bronze / silver / "bad gold"),
loads referentially-consistent retail mock data, runs an analyst workload to
populate `ACCOUNT_USAGE.QUERY_HISTORY`, and then walks through using the agent
tools to redesign the deliberately-broken gold layer into a proper dimensional
model with SCD2 dims and SQL transformations.

The intended audiences are demos, regression testing for the agent tools, and
training for consultants who want to see the full pipeline end to end.

## Shared-account safety: the nonce

Because consultants often share a single Snowflake account, every database,
schema, role, and warehouse this demo creates carries a **6-char nonce**
appended to its name (e.g. `DEMO_BRONZE_K4F2XR`, `DEMO_AGENT_RW_K4F2XR`,
`DEMO_WH_K4F2XR`). The nonce is generated on first run of `./run.sh` and
persisted in `build/.nonce` for the rest of the demo. `./run.sh teardown`
removes `build/` so the next run mints a fresh nonce.

If you want to see your current nonce: `./run.sh nonce`.

In the rest of this README, `<NONCE>` is shorthand for that value.

## Prerequisites

1. **Toolkit CLI installed and on `PATH`.** Verify with `toolkit --version`.
   If it isn't on `PATH`, run `toolkit admin shell` first.
2. **A Snowflake account you can write to.** The demo creates three databases
   (`DEMO_BRONZE_<NONCE>`, `DEMO_SILVER_<NONCE>`, `DEMO_GOLD_<NONCE>`), one
   role (`DEMO_AGENT_RW_<NONCE>`), and one warehouse (`DEMO_WH_<NONCE>`, XS).
   You need rights to create those and to read
   `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` (typically `ACCOUNTADMIN` or a role
   granted `IMPORTED PRIVILEGES` on the SNOWFLAKE database).
3. **A keypair for your Snowflake user.** Password auth works too — see
   "Authentication tweaks" below for the toolkit.conf change.
4. **Snowflake JDBC driver on the toolkit's driver path.** If you've already
   run any toolkit Snowflake command, you're fine.
5. **An LLM the agent commands can call.** `agent discovery-build`,
   `agent model-data`, `agent discovery`, and `agent pipeline-build` all
   make LLM calls.
    - **If you're a phData consultant**, you don't have to do anything —
      `toolkit.conf` falls back to Amazon Bedrock automatically when no
      explicit `llmClient` block is configured, and the toolkit auth flow
      brokers Bedrock access for phData users behind the scenes.
    - **Otherwise**, add an `llmClient { ... }` block to
      [toolkit.conf](toolkit.conf) pointing at whichever provider you have
      credentials for. See "LLM provider" below.

## One-time setup

`cd` into the demo directory — every command below assumes you're here:

```bash
cd demo/agent-pipeline
```

Mint a nonce (or just let the first `./run.sh` subcommand do it for you):

```bash
./run.sh nonce
# → Using nonce: K4F2XR  (objects will be named e.g. DEMO_BRONZE_K4F2XR)
```

Export the env vars consumed by `toolkit.conf`. **Set `SNOWFLAKE_WAREHOUSE`
to your nonced demo warehouse `DEMO_WH_<NONCE>` *after* you run `provision`.**
For the first `provision` step set it to any existing warehouse you have rights
to use — provision needs *some* warehouse to execute its DDL.

```bash
export SNOWFLAKE_ACCOUNT='your_org-your_account'
export SNOWFLAKE_USER='YOUR_USERNAME'
export SNOWFLAKE_ROLE='ACCOUNTADMIN'              # or whatever has provision rights
export SNOWFLAKE_WAREHOUSE='SOME_EXISTING_WH'     # change to DEMO_WH_<NONCE> after provision
export SNOWFLAKE_PRIVATE_KEY_PATH='/abs/path/to/rsa_key.p8'
```

## Phase 1: Provision the warehouse

```bash
./run.sh provision
```

What this does: `toolkit provision apply --approve` against [./stack](stack)
with `nonce` injected via `provision.variables` in [toolkit.conf](toolkit.conf).
Creates `DEMO_BRONZE_<NONCE>`, `DEMO_SILVER_<NONCE>`, `DEMO_GOLD_<NONCE>`, each
with a `MAIN` schema, a `DEMO_AGENT_RW_<NONCE>` role with privileges on all
three, and a `DEMO_WH_<NONCE>` XS warehouse.

After this step, switch your warehouse env var:

```bash
export SNOWFLAKE_WAREHOUSE="DEMO_WH_$(./run.sh nonce | awk '/Using nonce/{print $3}')"
```

Verify in Snowsight: `SHOW DATABASES LIKE 'DEMO_%_<NONCE>'` returns three rows.

## Phase 2: Generate raw bronze data

```bash
./run.sh load-bronze
```

What this does: renders [datagen/retail-bronze-spec.yaml](datagen/retail-bronze-spec.yaml)
into `build/datagen/retail-bronze-spec.yaml` with the nonce substituted, then
runs `toolkit datagen jdbc demo_sf build/datagen/retail-bronze-spec.yaml`.
Creates seven raw operational tables (`CUSTOMERS_RAW`, `PRODUCTS_RAW`,
`PRODUCT_CATEGORIES_RAW`, `STORES_RAW`, `STORE_LOCATIONS_RAW`, `ORDERS_RAW`,
`ORDER_LINES_RAW`) in `DEMO_BRONZE_<NONCE>.MAIN` and fills them with
referentially consistent mock data — roughly 1k customers, 200 products, 5k
orders, 15k order lines.

Bronze is deliberately raw and ugly: VARCHAR-heavy, natural keys, nullable
attributes via the `density` knob, no `DIM_DATE`. Silver is where the work happens.

## Phase 3: Build the clean silver star

```bash
./run.sh build-silver
```

What this does: renders [sql/10_silver_ddl.sql](sql/10_silver_ddl.sql) and
[sql/11_silver_inserts.sql](sql/11_silver_inserts.sql) into `build/sql/` with
the nonce substituted, then runs `toolkit ds exec` against each. Builds a proper
retail star in `DEMO_SILVER_<NONCE>.MAIN`: `DIM_CUSTOMER`, `DIM_PRODUCT`,
`DIM_PRODUCT_CATEGORY`, `DIM_STORE`, `DIM_STORE_LOCATION`, `DIM_DATE`,
`FACT_SALES`. Surrogate keys minted via `HASH()` on bronze natural keys. Proper
types, cleaned attributes, conformed dimensions.

This silver layer is what a competent data team would ship. It is the **input**
to the bad-gold load and the **source of truth** the new gold model will be
built from.

## Phase 4: Build the deliberately-bad gold layer

```bash
./run.sh build-bad-gold
```

What this does: renders three SQL files into `build/sql/` with the nonce
substituted, then runs `toolkit ds exec` against each —
[20_gold_bad_ddl.sql](sql/20_gold_bad_ddl.sql),
[21_gold_bad_inserts.sql](sql/21_gold_bad_inserts.sql), and
[22_gold_bad_dim_overwrite.sql](sql/22_gold_bad_dim_overwrite.sql).

Materializes two anti-patterns that the agent tools will later be asked to fix:

1. **`GOLD_SALES_FULL` — denormalized "one big table".** Order-line grain rows
   with every dim attribute and every header column flattened in. Aggregates
   double-count header-level facts. No clear grain documented. No surrogate
   keys.
2. **`GOLD_CUSTOMER_SNAPSHOT` / `GOLD_PRODUCT_SNAPSHOT` — overwrite-in-place
   dimensions.** `TRUNCATE` + `INSERT` every run. Prior values are lost. No
   SCD2 history. Any historical question ("what was this customer's email on
   the day of order X?") cannot be answered.

These two patterns are exactly what `agent model-data` is designed to
diagnose and replace.

## Phase 5: Simulate an analyst workload

```bash
./run.sh simulate-workload
```

What this does: runs [sql/30_workload_queries.sql](sql/30_workload_queries.sql)
five times against the bad gold. Override iteration count with
`WORKLOAD_LOOPS=N ./run.sh simulate-workload`.

The queries look like real BI / analyst work: revenue by year/quarter/category,
top customers, weekend vs weekday, cohort joins. Repeated invocations give the
history clustering and lineage parser non-trivial signal to work with.

### ⚠️ Wait for ACCOUNT_USAGE latency

This is the single biggest place this demo trips up. `ds history` reads
`SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`, which has **45 minutes to 3 hours of
latency** after a query lands. The queries are immediately visible in
`INFORMATION_SCHEMA.QUERY_HISTORY` but that's session-scoped — the agent tools
need the account-wide view.

**Plan for ~1 hour of wall-clock between `simulate-workload` and the next phase.**

To check progress:

```sql
SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TEXT ILIKE '%GOLD_SALES_FULL%'
  AND START_TIME > DATEADD(hour, -2, CURRENT_TIMESTAMP());
```

When that returns more than a handful, you're ready.

---

## Agent walkthrough

The rest of the demo is intentionally **not** wrapped in `run.sh`. Copy-paste
each command, read what it produces, and move on. This is where the learning
happens.

> **Tip:** `./run.sh agent-commands` prints the whole walkthrough below with
> the current nonce already interpolated into the `--rewrite-tables` /
> `--replace-tables` flags. Use it as a copy-paste source.

All commands are run from this directory (`demo/agent-pipeline`).

### Step 0: export the nonce into your shell

`toolkit.conf` references `${DEMO_NONCE}` in `provision.variables`, so any raw
`toolkit ...` command run outside `run.sh` will fail to parse the config
without it. Export it once per shell session:

```bash
eval "$(./run.sh env)"
```

You'll see something like `export DEMO_NONCE=K4F2XR` get evaluated. After this
the rest of the walkthrough is plain copy-paste.

### Step 1: `toolkit ds scan demo_sf` (filter already configured)

```bash
toolkit ds scan demo_sf
```

**What it does:** Scans table/view/column metadata into a Scan snapshot.

**Why it matters here:** In a shared Snowflake account, an unscoped scan
would fan out across every other consultant's databases and turn a fast
demo into a slow one. The `demo_sf` datasource in [toolkit.conf](toolkit.conf)
declares a `filters { patterns = [...] }` block that pins this — and every
subsequent `toolkit ds *` command — to your three nonced databases
(`DEMO_BRONZE_<NONCE>.MAIN.*`, `DEMO_SILVER_<NONCE>.MAIN.*`,
`DEMO_GOLD_<NONCE>.MAIN.*`). The snapshot this step writes is reused by
`ds lineage` (step 3) and `agent discovery-build` (step 4), so you only pay
the scan cost once.

After step 1 completes you can address the scan snapshot explicitly as
`<datasource>:scan:latest`, which `agent discovery-build` accepts directly
to pin to a specific scan.

### Step 2: `toolkit ds history demo_sf --user $SNOWFLAKE_USER --lookback 2`

```bash
toolkit ds history demo_sf --user "$SNOWFLAKE_USER" --lookback 2
```

**What it does:** Pulls the last **2 days** of queries from
`SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` filtered to **your user only**, and
stores them in a local DuckDB snapshot. Deduplicates by normalized query hash
so repeated analyst queries collapse to single shapes.

**Why it matters here:** In a shared Snowflake account, other consultants are
also running their own workloads — without `--user` filtering, the history
snapshot would be a noisy mix of everyone's queries. `--lookback 2` keeps the
window tight to what *you* just ran in Phase 5.

Downstream lineage and discovery-build use the history as the source of "what
tables actually get queried together". Without real workload (and the
`ACCOUNT_USAGE` latency wait), the lineage graph has nothing to chew on.

### Step 3: `toolkit ds lineage demo_sf`

```bash
toolkit ds lineage demo_sf
```

**What it does:** Parses the deduped history snapshot, extracts the read/write
table sets from each query, and builds table→table (and column→column) lineage
edges into a DuckDB snapshot.

**Why it matters here:** Tells `discovery-build` which tables are actually
related, beyond what FK declarations claim. In particular, it'll surface that
`GOLD_SALES_FULL` is derived from every silver dim and the fact — useful
context for the model-data step.

#### Inspect the lineage for a silver table

Once the snapshot is built, the same command can interrogate it. Pick a silver
table — say the silver fact `FACT_SALES` — and look at it two ways.

**`--lookup` — upstream and downstream lineage for a table.** Renders the
read→write graph as a tree. The argument is matched with `ILIKE`, so the `%`
wildcard saves you typing the nonce-qualified name:

```bash
toolkit ds lineage demo_sf --lookup '%FACT_SALES'
```

This surfaces the headline of the demo: `FACT_SALES` (and the silver dims)
feeding **downstream** into `GOLD_SALES_FULL` — the exact derivation the
model-data step later untangles.

**`--table` — comprehensive metadata for one table.** Prints table stats plus
per-column usage (how often each column is selected / filtered / joined /
grouped) and the top reader and writer query patterns. Address the silver table
explicitly (it's exact-or-`ILIKE`, and `${DEMO_NONCE}` is exported from Step 0):

```bash
toolkit ds lineage demo_sf --table "DEMO_SILVER_${DEMO_NONCE}.MAIN.FACT_SALES"
```

Both are read-only views over the snapshot you just built — run them as often
as you like without re-parsing history.

### Step 4: `toolkit agent discovery-build demo_sf:scan:latest`

```bash
toolkit agent discovery-build demo_sf:scan:latest
```

**What it does:** Builds a single warehouse-wide DuckDB index combining
catalog metadata, the history snapshot from Step 2, the lineage from Step 3,
and (optionally) data profiles. Validates join candidates against actual data.

**Why `:scan:latest`?** Passing the explicit scan selector pins the build to
the snapshot you produced in Step 1 rather than letting `discovery-build`
auto-run a fresh scan. Plain `toolkit agent discovery-build demo_sf` also
works — the datasource-level filter in `toolkit.conf` keeps any auto-scan
scoped to your three databases — but addressing the existing snapshot
directly is cheaper and reproducible.

**Why it matters here:** Both `agent model-data` and `agent discovery`
query this index with `--use-index` so they reason over the *real* shape of
the account — including which join paths actually have signal — not just
what the catalog says.

### Step 5: `toolkit agent model-data demo_sf ...`

`${DEMO_NONCE}` below is the shell variable you exported in Step 0 (via
`eval "$(./run.sh env)"`), so this is copy-paste as-is.

```bash
toolkit agent model-data demo_sf \
    --use-case agent/model-data-use-case.md \
    --questions agent/model-data-questions.txt \
    --rewrite-tables "DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_SALES_FULL" \
    --replace-tables "DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_CUSTOMER_SNAPSHOT,DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_PRODUCT_SNAPSHOT" \
    --use-index \
    --target-platform snowflake \
    --tooling sql \
    --output ./data-model-out
```

**What it does:** Reads the use-case doc and business questions, queries the
discovery-build index for the source/replace tables, and emits a folder of
`DiscoveryConfig` YAML files — one per fact and dimension in the redesigned
gold — plus a `rationale.md` explaining the grain choice, join graph, and SCD
strategy for each table.

**Why it matters here:** This is the payoff. The OBT (`GOLD_SALES_FULL`) gets
broken back into a star at a documented grain. The two overwrite-pattern
snapshot dims get SCD2 plans. The emitted YAMLs are the input to Step 6.

Inspect the output:

```bash
ls data-model-out/             # rationale.md, specs/
ls data-model-out/specs/       # one DiscoveryConfig per fact/dim
cat data-model-out/rationale.md
```

### Step 6: `toolkit agent discovery demo_sf <each emitted YAML>`

Two things to know about `agent discovery`'s output layout:

1. `agent model-data` writes its per-table configs into
   `data-model-out/specs/*.yaml` (a sibling of `rationale.md`), so the loop
   iterates that subdirectory, not the top-level `data-model-out/`.
2. `agent discovery` always writes its output as
   `<output-dir>/data-contract.json` — the YAML's `name:` field does **not**
   change the filename. To avoid clobbering each contract with the next, give
   every discovery invocation its own output subdirectory:

```bash
for f in data-model-out/specs/*.yaml; do
    name=$(basename "$f" .yaml)
    toolkit agent discovery demo_sf "$f" \
        --use-index \
        --output "./discovery-out/$name"
done
```

That produces `discovery-out/<name>/data-contract.json` per emitted YAML.

**What it does:** Resolves the modeling decision against actual data and the
discovery-build index. Produces one data contract JSON per table — column
types, constraints, source references, validation tests.

**Why it matters here:** model-data decides the shape; discovery turns each
shape into a reviewable, machine-readable contract. Each contract flags any
decision it wasn't confident enough to lock as an **item requiring your
review** — those are what you weigh in on in Step 7 before pipeline-build
consumes the contracts in Step 8.

### Step 7: `toolkit agent discovery demo_sf <config> --resolve <each contract>` — apply your review comments

Step 6 deliberately did **not** silently guess on low-confidence decisions. Each
contract's `discovery-report.txt` ends with an **ITEMS REQUIRING YOUR REVIEW**
section, backed by the `humanReviewItems` array in `data-contract.json` — a
complex transform it wants you to confirm, an ambiguous source, a business rule
it couldn't verify. For example, `dim_customer` surfaces:

```
1. [COMPLEX TRANSFORM] customer_age_band: CASE WHEN BIRTH_YEAR IS NULL ...
   Please verify this business logic.
   Resolution: <your comment here>
```

To resolve, open `discovery-out/<name>/data-contract.json`, find the matching
entry in `sourceToTarget.humanReviewItems`, and fill in its `comment` field with
a natural-language instruction — e.g. `"This age-band logic is correct, keep
it"` or `"Use a fixed reference date of DATE '2024-01-01' instead of
CURRENT_DATE"`. Then re-run discovery with `--resolve`:

```bash
# after editing comments into discovery-out/dim_customer/data-contract.json:
toolkit agent discovery demo_sf data-model-out/specs/dim_customer.yaml \
    --resolve discovery-out/dim_customer/data-contract.json
```

Or sweep every contract — those you left without comments are reported as
"nothing to resolve" and pass through unchanged, so the loop is safe to run
over all of them:

```bash
for d in discovery-out/*/; do
    name=$(basename "$d")
    toolkit agent discovery demo_sf "data-model-out/specs/$name.yaml" \
        --resolve "$d/data-contract.json"
done
```

> **Note:** `--resolve` still requires the positional `datasource` and `config`
> arguments even though it ignores them on this path, so just pass the same YAML
> you used in Step 6.

**What it does:** Applies each `comment` as an amendment to the contract via the
LLM (updating column mappings, joins, business rules, etc.), drops the resolved
items from `humanReviewItems`, marks the contract `approvedByHuman` when none
remain, and overwrites both `data-contract.json` and `discovery-report.txt` in
place. Pipeline-build metadata (tooling, target platform, target columns) is
structurally locked and round-trips unchanged.

**Why it matters here:** This is the human-in-the-loop checkpoint. pipeline-build
(Step 8) builds from a contract a human has signed off on, not from the agent's
unreviewed first draft.

### Step 8: `toolkit agent pipeline-build demo_sf --contract <each contract>`

Walk every per-table subdirectory, now that the contracts carry your resolved
review comments:

```bash
for d in discovery-out/*/; do
    name=$(basename "$d")
    toolkit agent pipeline-build demo_sf \
        --contract "$d/data-contract.json" \
        --output "./pipeline-out/$name"
done
```

**What it does:** Generates the SQL transformations for the new gold layer from
each contract — `CREATE TABLE` DDL plus initial/incremental load SQL — along
with data-quality tests and a mock-data spec, driven by a judge-feedback retry
loop that re-runs validations until the generated SQL passes or `--max-retries`
is hit.

**Why it matters here:** Closes the loop. The bad gold's replacement is now
living SQL, not a design doc.

Open `pipeline-out/` in your editor. Compare the generated `fct_sales` transform
to the old `GOLD_SALES_FULL`. Note the SCD2 logic in the new customer dim vs the
old `TRUNCATE` + `INSERT` in `22_gold_bad_dim_overwrite.sql`. That's the demo.

---

## Teardown

```bash
./run.sh teardown
```

`toolkit provision destroy --approve` drops `DEMO_BRONZE_<NONCE>`,
`DEMO_SILVER_<NONCE>`, `DEMO_GOLD_<NONCE>`, `DEMO_AGENT_RW_<NONCE>`, and
`DEMO_WH_<NONCE>`, then removes `build/` so the next run mints a fresh nonce.
Use this between runs to keep the account clean.

Local artifacts outside `build/` (`data-model-out/`, `discovery-out/`,
`pipeline-out/`, and the toolkit snapshot directory) are *not* removed by
teardown. Delete them by hand if you want a fully clean restart.

## Authentication tweaks

The default `toolkit.conf` uses keypair auth. If you prefer password auth,
replace the `properties` block in [toolkit.conf](toolkit.conf):

```hocon
properties {
    user = ${SNOWFLAKE_USER}
    role = ${SNOWFLAKE_ROLE}
    warehouse = ${SNOWFLAKE_WAREHOUSE}
    password = ${SNOWFLAKE_PASSWORD}
}
```

And `export SNOWFLAKE_PASSWORD=...` instead of `SNOWFLAKE_PRIVATE_KEY_PATH`.

## LLM provider

The agent commands (`discovery-build`, `model-data`, `discovery`,
`pipeline-build`) call an LLM. When no `llmClient` block is set in
[toolkit.conf](toolkit.conf), the toolkit defaults to **Amazon Bedrock** —
which is the right answer for phData consultants because the toolkit's auth
flow already brokers Bedrock access for phData users; nothing else needs to
be configured.

If you're not on the phData auth flow, add one of the following to
[toolkit.conf](toolkit.conf) as a top-level block (peer to `connections`,
`ds`, `provision`):

**OpenAI:**

```hocon
llmClient {
    type = openai
    model = "gpt-4.1-2025-04-14"     # any chat-completions model id
    url = "https://api.openai.com/v1"
    apiKey = ${OPENAI_API_KEY}        # or paste your key in directly (not recommended)
    requestTimeout = 60s
    retryThreshold = 3
}
```

**Anthropic:**

```hocon
llmClient {
    type = anthropic
    model = "claude-sonnet-4-5"        # or any other Anthropic model id
    url = "https://api.anthropic.com"
    apiKey = ${ANTHROPIC_API_KEY}
    retryThreshold = 3
}
```

Prefer `${OPENAI_API_KEY}` / `${ANTHROPIC_API_KEY}` HOCON env-var substitution
over literal keys so you don't accidentally commit a secret. The OpenAI and
Anthropic client configs also fall back to reading the env var directly if
`apiKey` is omitted entirely, so you can leave it out of the block and just
`export` it before running `toolkit`.

## Smoke test without a real Snowflake account

You can validate the stack YAML compiles without touching Snowflake:

```bash
toolkit provision apply --plan --approve
```

`--plan` mode prints the diff that *would* be applied without executing
anything against a Snowflake account. Useful when reviewing PRs that change
the stack.

## Notes for maintainers

- The provision stack under [stack/](stack) is a **standalone copy** of the
  pattern at `cli/src/main/resources/tutorial/provision/stack/`. Do not
  consolidate them — keeping this demo independent of the toolkit's tutorial
  files protects it from unrelated tutorial changes.
- The datagen spec at [datagen/retail-bronze-spec.yaml](datagen/retail-bronze-spec.yaml)
  is a **new** raw-operational shape. The existing test resource at
  `cli/src/test/resources/data-generation/snowflake-schema-spec.yaml` is the
  silver target shape, not bronze — the silver DDL/INSERT files in
  [sql/](sql) reproduce that shape from this demo's bronze.
- SQL files separate DDL from DML deliberately: every layer has `_ddl.sql` +
  `_inserts.sql`. No `CREATE TABLE AS SELECT`. This is realistic of how teams
  ship SQL and makes the `agent fix-sql` style demos cleaner.
- The nonce is plumbed two different ways: provision picks it up via
  `provision.variables.nonce` in [toolkit.conf](toolkit.conf) and the Jinja
  `{{nonce}}` tokens in [stack/](stack); SQL files and the datagen spec use
  the literal token `${DEMO_NONCE}` which `run.sh`'s `render_one` substitutes
  into `build/` before each `ds exec` / `datagen jdbc` call. Both paths read
  the same value from `build/.nonce`. Keep the two in sync if you rename it.
