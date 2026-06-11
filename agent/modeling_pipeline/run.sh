#!/usr/bin/env bash
#
# run.sh — mechanical phases of the agent-pipeline demo.
#
# Run from anywhere — the script cd's to its own location. Each subcommand
# wraps one Toolkit CLI invocation so the README can call them out one at a
# time.
#
# Shared-account safety: every database, schema, role, and warehouse name
# carries a per-checkout nonce (6 uppercase alnum chars). The nonce is
# generated on first run and persisted in build/.nonce so subsequent
# subcommands see the same names. `teardown` removes build/ so the next run
# gets a fresh nonce.
#
# The agent walkthrough (ds history, ds lineage, agent discovery-build,
# agent model-data, agent discovery, agent pipeline-build) is intentionally
# NOT wrapped here. See README.md "Agent walkthrough" — each step is meant to
# be copy-pasted by hand so consultants learn what they're running. Run
# `./run.sh agent-commands` to print those commands with the current nonce
# already interpolated.

set -euo pipefail

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEMO_DIR"

BUILD_DIR="$DEMO_DIR/build"
NONCE_FILE="$BUILD_DIR/.nonce"
WORKLOAD_LOOPS="${WORKLOAD_LOOPS:-5}"

require_env() {
    local missing=0
    for var in SNOWFLAKE_ACCOUNT SNOWFLAKE_USER SNOWFLAKE_ROLE SNOWFLAKE_WAREHOUSE SNOWFLAKE_PRIVATE_KEY_PATH; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: required env var $var is not set" >&2
            missing=1
        fi
    done
    if [[ $missing -ne 0 ]]; then
        exit 1
    fi
}

# Load or generate the nonce. Exports DEMO_NONCE.
load_nonce() {
    mkdir -p "$BUILD_DIR"
    if [[ ! -f "$NONCE_FILE" ]]; then
        # 6 random uppercase alnum chars from /dev/urandom
        local n
        n=$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c 6 || true)
        if [[ ${#n} -ne 6 ]]; then
            echo "ERROR: failed to generate a 6-char nonce" >&2
            exit 1
        fi
        echo "$n" >"$NONCE_FILE"
    fi
    DEMO_NONCE="$(cat "$NONCE_FILE")"
    export DEMO_NONCE
    echo "Using nonce: $DEMO_NONCE  (objects will be named e.g. DEMO_BRONZE_${DEMO_NONCE})"
}

# Replace the literal token ${DEMO_NONCE} with the current nonce value.
# Uses bash parameter expansion so we don't depend on `envsubst` (not standard
# on macOS). Substituting only this one token means any other shell-style
# tokens that happen to appear in the SQL are left untouched.
render_one() {
    local src="$1" dst="$2"
    local content
    content=$(<"$src")
    printf '%s\n' "${content//\$\{DEMO_NONCE\}/$DEMO_NONCE}" >"$dst"
}

# Render every templated SQL file and the datagen spec into build/.
materialize() {
    load_nonce
    mkdir -p "$BUILD_DIR/sql" "$BUILD_DIR/datagen"
    for src in sql/*.sql; do
        render_one "$src" "$BUILD_DIR/$src"
    done
    render_one datagen/retail-bronze-spec.yaml "$BUILD_DIR/datagen/retail-bronze-spec.yaml"
}

usage() {
    cat <<'EOF'
Usage: run.sh <subcommand>

Subcommands:
  provision           Apply the stack: DEMO_BRONZE_<nonce> / SILVER / GOLD, role, warehouse
  load-bronze         Generate raw retail data into DEMO_BRONZE_<nonce> via datagen jdbc
  build-silver        Apply silver DDL then INSERTs (DEMO_SILVER_<nonce> clean star)
  build-bad-gold      Apply bad-gold DDL then INSERTs and the dim-overwrite anti-pattern
  build-all           Run load-bronze, build-silver, build-bad-gold in sequence
  simulate-workload   Loop sql/30_workload_queries.sql (default 5x; override with WORKLOAD_LOOPS=N)
  agent-commands      Print the agent walkthrough commands with the current nonce substituted in
  env                 Print `export DEMO_NONCE=...` for the current nonce.
                      Use as: eval "$(./run.sh env)" — required before running any
                      raw `toolkit ...` command, because toolkit.conf references ${DEMO_NONCE}.
  nonce               Print the current nonce (generating one if needed)
  teardown            Drop everything via `provision destroy` and remove build/ (clears nonce)

The agent walkthrough commands are intentionally not wrapped. See README.md and
`./run.sh agent-commands`.
EOF
}

provision() {
    require_env
    load_nonce
    toolkit provision apply --approve
}

load_bronze() {
    require_env
    materialize
    toolkit datagen jdbc demo_sf "$BUILD_DIR/datagen/retail-bronze-spec.yaml"
}

build_silver() {
    require_env
    materialize
    toolkit ds exec demo_sf --file "$BUILD_DIR/sql/10_silver_ddl.sql"
    toolkit ds exec demo_sf --file "$BUILD_DIR/sql/11_silver_inserts.sql"
}

build_bad_gold() {
    require_env
    materialize
    toolkit ds exec demo_sf --file "$BUILD_DIR/sql/20_gold_bad_ddl.sql"
    toolkit ds exec demo_sf --file "$BUILD_DIR/sql/21_gold_bad_inserts.sql"
    toolkit ds exec demo_sf --file "$BUILD_DIR/sql/22_gold_bad_dim_overwrite.sql"
}

build_all() {
    load_bronze
    build_silver
    build_bad_gold
}

simulate_workload() {
    require_env
    materialize
    echo "Running workload ${WORKLOAD_LOOPS}x. Remember: ACCOUNT_USAGE has 45min-3hr latency before ds history will see these."
    for ((i = 1; i <= WORKLOAD_LOOPS; i++)); do
        echo "--- workload iteration $i / ${WORKLOAD_LOOPS} ---"
        toolkit ds exec demo_sf --file "$BUILD_DIR/sql/30_workload_queries.sql"
    done
}

env_export() {
    load_nonce >/dev/null
    printf 'export DEMO_NONCE=%s\n' "$DEMO_NONCE"
}

agent_commands() {
    load_nonce
    cat <<EOF

# ---- Agent walkthrough (copy-paste, one at a time) ----
# Nonce in use: $DEMO_NONCE

# 0. FIRST: export DEMO_NONCE into your current shell. toolkit.conf references
#    \${DEMO_NONCE} in provision.variables, so any raw \`toolkit ...\` command
#    will fail to parse the config without it.
eval "\$(./run.sh env)"

# 1. Scan your three nonced demo databases. The datasource-level
#    \`filters { patterns = [...] }\` in toolkit.conf already scopes this to
#    DEMO_BRONZE_${DEMO_NONCE} / DEMO_SILVER_${DEMO_NONCE} / DEMO_GOLD_${DEMO_NONCE} —
#    no --filter flag needed. The snapshot is reused by every downstream command.
toolkit ds scan demo_sf

# 2. Pull the last 2 days of YOUR user's query history.
toolkit ds history demo_sf --user "\$SNOWFLAKE_USER" --lookback 2

# 3. Derive table/column lineage from the history snapshot.
toolkit ds lineage demo_sf

# 3a. Inspect the lineage for a silver table two ways (read-only views over the
#     snapshot just built). --lookup renders the upstream/downstream tree
#     (ILIKE, so % avoids typing the nonce); --table prints full metadata,
#     per-column usage, and top reader/writer queries for one table.
toolkit ds lineage demo_sf --lookup '%FACT_SALES'
toolkit ds lineage demo_sf --table "DEMO_SILVER_${DEMO_NONCE}.MAIN.FACT_SALES"

# 4. Build the warehouse-wide discovery index. Pass the scan selector
#    (\`<datasource>:scan:latest\`) to pin the build to the snapshot from step 1
#    instead of triggering a fresh scan.
toolkit agent discovery-build demo_sf:scan:latest

# 5. Design the new dimensional model to replace the bad gold.
toolkit agent model-data demo_sf \\
    --use-case agent/model-data-use-case.md \\
    --questions agent/model-data-questions.txt \\
    --rewrite-tables DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_SALES_FULL \\
    --replace-tables DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_CUSTOMER_SNAPSHOT,DEMO_GOLD_${DEMO_NONCE}.MAIN.GOLD_PRODUCT_SNAPSHOT \\
    --use-index \\
    --target-platform snowflake \\
    --tooling sql \\
    --output ./data-model-out

# 6. For each emitted YAML, run discovery against the existing index
#    (--use-index reuses the step 4 build, no re-scanning).
#    Notes:
#      - model-data emits DiscoveryConfigs into data-model-out/specs/ (not
#        the top level — rationale.md lives there too).
#      - discovery always writes <output-dir>/data-contract.json — the YAML
#        name does NOT drive the filename. Give each invocation its own subdir
#        so contracts don't overwrite each other.
for f in data-model-out/specs/*.yaml; do
    name=\$(basename "\$f" .yaml)
    toolkit agent discovery demo_sf "\$f" \\
        --use-index \\
        --output "./discovery-out/\$name"
done

# 7. Resolve the "ITEMS REQUIRING YOUR REVIEW" each contract surfaced. First add
#    a natural-language \`comment\` to the humanReviewItems you want to amend in
#    discovery-out/<name>/data-contract.json, then apply them with --resolve.
#    The datasource + config args are required by the CLI but ignored on the
#    --resolve path, so pass the same YAML from step 6. Contracts with no
#    comments are left unchanged, so sweeping over all of them is safe.
for d in discovery-out/*/; do
    name=\$(basename "\$d")
    toolkit agent discovery demo_sf "data-model-out/specs/\$name.yaml" \\
        --resolve "\$d/data-contract.json"
done

# 8. For each per-table contract subdir, run pipeline-build:
for d in discovery-out/*/; do
    name=\$(basename "\$d")
    toolkit agent pipeline-build demo_sf \\
        --contract "\$d/data-contract.json" \\
        --output "./pipeline-out/\$name"
done
EOF
}

teardown() {
    require_env
    load_nonce
    toolkit provision destroy --approve
    rm -rf "$BUILD_DIR"
    echo "Removed $BUILD_DIR (next run will mint a new nonce)."
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    case "$1" in
        provision)         provision ;;
        load-bronze)       load_bronze ;;
        build-silver)      build_silver ;;
        build-bad-gold)    build_bad_gold ;;
        build-all)         build_all ;;
        simulate-workload) simulate_workload ;;
        agent-commands)    agent_commands ;;
        env)               env_export ;;
        nonce)             load_nonce ;;
        teardown)          teardown ;;
        -h|--help|help)    usage ;;
        *)
            echo "Unknown subcommand: $1" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
