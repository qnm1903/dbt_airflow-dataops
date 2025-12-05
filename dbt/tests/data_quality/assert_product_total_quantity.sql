-- Singular Test: Product Total Quantity Accuracy
-- Purpose: Validates product quantity sold matches between gold and silver layers
-- Returns: Rows where gold layer quantity differs from calculated silver layer quantity

with gold_qty as (
    select 
        product_id,
        total_quantity_sold
    from {{ ref('gld_product_performance') }}
    where total_orders > 0
),

silver_qty as (
    select 
        product_id,
        sum(order_quantity) as calculated_quantity
    from {{ ref('slvr_sales_orders') }}
    group by product_id
)

select
    g.product_id,
    g.total_quantity_sold as gold_quantity,
    s.calculated_quantity as silver_quantity
from gold_qty g
inner join silver_qty s on g.product_id = s.product_id
where g.total_quantity_sold != s.calculated_quantity
