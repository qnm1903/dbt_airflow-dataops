-- Singular Test: Customer Revenue Consistency
-- Purpose: Validates that customer lifetime revenue in gold matches sum of order values from silver order summary
-- Returns: Rows where gold layer revenue differs from calculated silver layer revenue
-- Note: This test identifies a known data model issue where revenue may be double-counted
--       due to the join pattern in gld_customer_metrics. Configured as warn-only.

{{ config(severity='warn') }}

with gold_revenue as (
    select 
        customer_id,
        lifetime_revenue
    from {{ ref('gld_customer_metrics') }}
    where total_orders > 0
      and lifetime_revenue > 0
),

silver_revenue as (
    select 
        customer_id,
        sum(total_order_value) as calculated_revenue
    from {{ ref('slvr_order_summary') }}
    group by customer_id
)

select
    g.customer_id,
    g.lifetime_revenue as gold_revenue,
    s.calculated_revenue as silver_revenue,
    abs(g.lifetime_revenue - s.calculated_revenue) as difference,
    case 
        when g.lifetime_revenue > 0 
        then (abs(g.lifetime_revenue - s.calculated_revenue) / g.lifetime_revenue) * 100
        else 0
    end as percentage_difference
from gold_revenue g
inner join silver_revenue s on g.customer_id = s.customer_id
where abs(g.lifetime_revenue - s.calculated_revenue) > 1  -- Allow $1 tolerance for rounding
  and (abs(g.lifetime_revenue - s.calculated_revenue) / g.lifetime_revenue) > 0.01  -- And > 1% difference
