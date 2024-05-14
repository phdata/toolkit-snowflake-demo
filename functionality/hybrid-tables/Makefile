SHELL := /bin/bash -euo pipefail
DATABASE := hybrid_table_demo
SCALE := 1
SESSION_ID := $(shell uuidgen)

.PHONY: build templates build queries setup build migrate benchmark reset-benchmark datagen datagen-columnar datagen-hybrid query-columnar-select query-hybrid-select query-columnar-join query-hybrid-join clean truncate-hybrid-customer truncate-hybrid-product truncate-hybrid-order-history truncate-hybrid truncate-columnar-customer truncate-columnar-product truncate-columnar-order-history truncate-columnar truncate

# Setup
database:
	toolkit ds exec snowflake --query 'CREATE DATABASE IF NOT EXISTS $(HYBRID_DEMO_DATABASE)'

benchmark:
	mkdir -p build
	make migrate
	make templates
	make run-benchmark

migrate: database
	flyway migrate

templates:
	mkdir -p build/queries/{columnar,hybrid}
	for file in templates/queries/*.sql; do \
		TYPE=columnar SESSION_ID=$(SESSION_ID) mo -u $${file} > build/queries/columnar/`basename $${file}`; \
		TYPE=hybrid SESSION_ID=$(SESSION_ID)  mo -u $${file} > build/queries/hybrid/`basename $${file}`; \
	done
	echo $(SESSION_ID)> build/SESSION_ID
	mkdir -p build/specs
	DATABASE=$(HYBRID_DEMO_DATABASE) SCHEMA=columnar mo -u templates/spec.yaml > build/specs/columnar-table-spec.yaml
	DATABASE=$(HYBRID_DEMO_DATABASE) SCHEMA=hybrid mo -u templates/spec.yaml > build/specs/hybrid-table-spec.yaml

# Benchmark
datagen-columnar: truncate-columnar
	toolkit datagen jdbc snowflake --spec build/specs/columnar-table-spec.yaml

datagen-hybrid: truncate-hybrid
	toolkit datagen jdbc snowflake --spec build/specs/hybrid-table-spec.yaml

datagen-columnar-single: truncate-columnar
	toolkit datagen jdbc snowflake  --batch-size 10 --scale 1 --threads 3 --spec  build/specs/columnar-table-spec.yaml

datagen-hybrid-single: truncate-hybrid
	toolkit datagen jdbc snowflake  --batch-size 10 --scale 1 --threads 3 --spec build/specs/hybrid-table-spec.yaml

add-hybrid-indexes:
	benchmark "@" toolkit ds exec snowflake --file build/queries/add-hybrid-indexes.sql

hybrid-queries:
	for file in build/queries/hybrid/*.sql; do \
		toolkit ds exec snowflake --file $${file}; \
	done

columnar-queries:
	for file in build/queries/columnar/*.sql; do \
		toolkit ds exec snowflake --file $${file}; \
	done

queries:
	make hybrid-queries
	make columnar-queries

run-benchmark:
	make datagen-hybrid-single
	make datagen-columnar-single
	make datagen-hybrid
	make datagen-columnar
	make queries
	make results
#	make add-hybrid-indexes
#	make hybrid-queries

results:
	SESSION_ID=`cat build/SESSION_ID` mo templates/queries/query-results.sql > build/queries/query-results.sql
	toolkit ds exec snowflake --file build/queries/query-results.sql

datagen: datagen-columnar datagen-hybrid

# Cleanup
clean:
	toolkit ds exec snowflake --query 'DROP DATABASE IF EXISTS $(HYBRID_DEMO_DATABASE)'
	rm -rf build

truncate-hybrid-customer:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).hybrid.customer'

truncate-hybrid-product:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).hybrid.product'

truncate-hybrid-order-history:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).hybrid.order_history'

truncate-hybrid: truncate-hybrid-customer truncate-hybrid-product truncate-hybrid-order-history

truncate-columnar: truncate-columnar-customer truncate-columnar-product truncate-columnar-order-history

truncate-columnar-customer:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).columnar.customer'

truncate-columnar-product:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).columnar.product'

truncate-columnar-order-history:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE $(HYBRID_DEMO_DATABASE).columnar.order_history'

truncate: truncate-hybrid-customer truncate-hybrid truncate-columnar
