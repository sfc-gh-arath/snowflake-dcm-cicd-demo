DEFINE TABLE SALES_CICD{{env}}.RAW.ORDERS (
    ORDER_ID NUMBER COMMENT 'Unique order identifier',
    CUSTOMER_ID NUMBER COMMENT 'Customer identifier',
    AMOUNT NUMBER(10, 2) COMMENT 'Order amount in USD',
    ORDER_TS TIMESTAMP_NTZ COMMENT 'Order timestamp'
)
CHANGE_TRACKING = TRUE
COMMENT = 'Raw orders';
