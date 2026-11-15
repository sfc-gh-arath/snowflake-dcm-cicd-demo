/***
Demo CI CD process based on
/Users/arath/Documents/snowflake/training&manuals/ci_cd/snowflake-dcm-cicd-demo/README.md

**/

SHOW DEPLOYMENTS IN DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV;   -- alias = gh-<run> <commit sha>
SHOW ENTITIES    IN DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV;   -- managed objects

-- Every deployment keeps the exact source + rendered files
LIST 'snow://project/DCM_DEMO.PROJECTS.SALES_CICD_DEV/deployments/deployment$3/';

SELECT * FROM SEMANTIC_VIEW(SALES_CICD_DEV.ANALYTICS.SV_SALES
  METRICS orders.TOTAL_REVENUE, orders.ORDER_COUNT DIMENSIONS orders.ORDER_DATE)
ORDER BY ORDER_DATE DESC;

show git repositories in account;
