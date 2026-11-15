-- Smoke tests run by CI after each deployment. Usage:
--   snow sql -x -f tests/smoke_test.sql --variable env=DEV
USE WAREHOUSE SALES_CICD_WH_&{env};

-- Stored procedure + table
CALL SALES_CICD_&{env}.APPS.SP_LOAD_ORDERS(100);

-- Dynamic table
ALTER DYNAMIC TABLE SALES_CICD_&{env}.ANALYTICS.DT_DAILY_SALES REFRESH;
SELECT COUNT(*) AS DAYS_WITH_SALES FROM SALES_CICD_&{env}.ANALYTICS.DT_DAILY_SALES;

-- Semantic view
SELECT *
FROM SEMANTIC_VIEW(SALES_CICD_&{env}.ANALYTICS.SV_SALES
    METRICS orders.TOTAL_REVENUE, orders.ORDER_COUNT
    DIMENSIONS orders.ORDER_DATE)
ORDER BY ORDER_DATE DESC
LIMIT 5;

-- Notebook (Code Bundle)
EXECUTE CODE BUNDLE SALES_CICD_&{env}.APPS.SALES_ANALYSIS
    ENTRYPOINT = 'sales_analysis.ipynb'
    ARGUMENTS = ('--env', '&{env}');
