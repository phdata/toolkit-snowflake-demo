SHELL := /bin/bash -euo pipefail
DYNAMIC_DEMO_DATABASE := dynamic_table_demo
SCALE := 1
SESSION_ID := $(shell uuidgen)
.PHONY: templates


# Setup
database:
	toolkit ds exec snowflake --query 'CREATE DATABASE IF NOT EXISTS $(DYNAMIC_DEMO_DATABASE)'

run:
	make database
	make migrate
	make templates
	make dynamic-create
	make datagen
	make dynamic-select

save-seed:
	echo -n `date +%s` > build/seed

increment-seed:
	# Read the current seed value from the file
	SEED=$$(cat build/seed);NEW_SEED=$$(($$SEED + 1));echo -n $$NEW_SEED > build/seed

truncate-sources:
	toolkit ds exec snowflake --query 'TRUNCATE TABLE IF EXISTS $(DYNAMIC_DEMO_DATABASE).demo.product;'
	toolkit ds exec snowflake --query 'TRUNCATE TABLE IF EXISTS $(DYNAMIC_DEMO_DATABASE).demo.customer;'
	toolkit ds exec snowflake --query 'TRUNCATE TABLE IF EXISTS $(DYNAMIC_DEMO_DATABASE).demo.location;'
	toolkit ds exec snowflake --query 'TRUNCATE TABLE IF EXISTS $(DYNAMIC_DEMO_DATABASE).demo.order_history;'

migrate: database
	flyway migrate

templates:
	mkdir -p build/queries
	for file in templates/queries/*.sql; do \
		TYPE=columnar SESSION_ID=$(SESSION_ID) mo -u $${file} > build/queries/`basename $${file}`; \
	done
	echo $(SESSION_ID)> build/SESSION_ID
	mkdir -p build/specs
	DATABASE=$(DYNAMIC_DEMO_DATABASE) SCHEMA=demo mo -u templates/spec.yaml > build/specs/columnar-table-spec.yaml

# Demo
datagen: save-seed templates
	toolkit datagen jdbc snowflake --spec build/specs/columnar-table-spec.yaml --seed `cat build/seed`

make datagen-increment: increment-seed
	toolkit datagen jdbc snowflake --append --spec build/specs/columnar-table-spec.yaml --seed `cat build/seed`

dynamic-create:
	toolkit ds exec snowflake --file build/queries/dynamic-create.sql

dynamic-select:
	toolkit ds exec snowflake --file build/queries/dynamic-select.sql


# Cleanup
clean:
	toolkit ds exec snowflake --query 'DROP DATABASE IF EXISTS $(DYNAMIC_DEMO_DATABASE)'
	toolkit ds exec snowflake --query 'DROP WAREHOUSE IF EXISTS DYNAMIC_TABLE_DEMO_WH'

	rm -rf build

drop-dynamic-table:
	toolkit ds exec snowflake --query "DROP TABLE IF EXISTS $(DYNAMIC_DEMO_DATABASE).demo.denormalized;"
