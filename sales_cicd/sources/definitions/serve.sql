DEFINE SEMANTIC VIEW SALES_CICD{{env}}.ANALYTICS.SV_SALES
    TABLES (
        orders AS SALES_CICD{{env}}.RAW.ORDERS
            PRIMARY KEY (ORDER_ID)
            WITH SYNONYMS = ('sales', 'transactions')
            COMMENT = 'Customer orders'
    )
    DIMENSIONS (
        orders.ORDER_DATE AS DATE(orders.ORDER_TS)
            COMMENT = 'Date the order was placed',
        orders.CUSTOMER_ID AS orders.CUSTOMER_ID
            COMMENT = 'Customer identifier'
    )
    METRICS (
        orders.TOTAL_REVENUE AS SUM(orders.AMOUNT)
            COMMENT = 'Total revenue in USD',
        orders.ORDER_COUNT AS COUNT(orders.ORDER_ID)
            COMMENT = 'Number of orders'
    )
    COMMENT = 'Sales metrics for Cortex Analyst';
