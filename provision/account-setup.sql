-- Create a warehouse
USE ROLE SYSADMIN;
CREATE OR REPLACE WAREHOUSE PHDATA_WH
  WAREHOUSE_SIZE = XSMALL
  WAREHOUSE_TYPE = STANDARD
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED=TRUE
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 1
  SCALING_POLICY = 'STANDARD'
  COMMENT = 'Warehouse for the phData Provision tool';

-- Create a role for the provision user
USE ROLE SECURITYADMIN;
CREATE OR REPLACE ROLE PROVISION_ADMIN
  COMMENT = 'Role for the phData Provision tool';

-- Grant the role access to create objects, users, roles, and privileges
GRANT ROLE SYSADMIN TO ROLE PROVISION_ADMIN;
GRANT ROLE SECURITYADMIN TO ROLE PROVISION_ADMIN;
GRANT ROLE USERADMIN TO ROLE PROVISION_ADMIN;

-- Create the user
USE ROLE USERADMIN;
CREATE OR REPLACE USER PROVISION_USER
  LOGIN_NAME = 'PROVISION_USER'
  DISPLAY_NAME = 'PROVISION_USER'
  DEFAULT_WAREHOUSE = PHDATA_WH
  DEFAULT_ROLE = PROVISION_ADMIN
  COMMENT = 'User for the phData Provision tool';

-- Grant the user access to the role
USE ROLE SECURITYADMIN;
GRANT ROLE PROVISION_ADMIN TO USER PROVISION_USER; 

-- Grant ACCOUNTADMIN to the provision role (required to manage RESOURCE MONITORS)
USE ROLE ACCOUNTADMIN;
GRANT ROLE ACCOUNTADMIN TO ROLE PROVISION_ADMIN;

USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE RESOURCE MONITOR PHDATA_MONITOR WITH 
  CREDIT_QUOTA = 15
  FREQUENCY = WEEKLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS 
    ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;
    
ALTER WAREHOUSE PHDATA_WH SET RESOURCE_MONITOR = PHDATA_MONITOR;

-- Additional setup for custom roles used by the provision tool as object owners
USE ROLE useradmin;
CREATE OR REPLACE ROLE policy_admin;
CREATE OR REPLACE ROLE tag_admin;
CREATE OR REPLACE ROLE alert_admin;

USE ROLE securityadmin;
GRANT ROLE policy_admin TO ROLE provision_admin;
GRANT ROLE policy_admin TO USER provision_user;
GRANT ROLE tag_admin TO ROLE provision_admin;
GRANT ROLE tag_admin TO USER provision_user;
GRANT ROLE alert_admin TO ROLE provision_admin;
GRANT ROLE alert_admin TO USER provision_user;
