-- Test: No duplicate order detail IDs should exist
SELECT
    sales_order_detail_id,
    COUNT(*) as duplicate_count
FROM {{ ref('brnz_sales_orders') }}
GROUP BY sales_order_detail_id
HAVING COUNT(*) > 1
