{{ config(materialized='table') }}

-- Silver layer: Order-level summary aggregating order details into order headers
-- This intermediate model consolidates multiple order line items into order-level metrics
with sales_details as (
  select * from {{ ref('slvr_sales_orders') }}
),

order_aggregation as (
  select
    -- Order identifiers
    sales_order_id,
    sales_order_number,
    purchase_order_number,

    -- Date information (same for all lines in an order)
    min(order_date) as order_date,  -- Should be same for all lines, using min as safety
    min(due_date) as due_date,
    min(ship_date) as ship_date,
    min(order_status) as order_status,
    min(order_status_description) as order_status_description,
    min(order_channel) as order_channel,
    min(delivery_performance) as delivery_performance,
    min(days_to_due) as days_to_due,
    min(days_to_ship) as days_to_ship,
    min(days_early_late) as days_early_late,

    -- Customer and territory (same for all lines in an order)
    min(customer_id) as customer_id,
    min(customer_type) as customer_type,
    min(sales_person_id) as sales_person_id,
    min(territory_id) as territory_id,

    -- Order-level aggregations
    count(*) as total_line_items,
    count(distinct product_id) as unique_products,
    count(distinct category_name) as unique_categories,
    sum(order_quantity) as total_quantity,
    sum(line_total) as total_order_value,
    sum(discount_amount) as total_discount_amount,
    sum(gross_amount) as total_gross_amount,
    avg(unit_price) as avg_unit_price,
    min(unit_price) as min_unit_price,
    max(unit_price) as max_unit_price,

    -- Discount analysis at order level
    sum(case when has_discount = 1 then 1 else 0 end) as discounted_line_items,
    case
      when count(*) > 0
        then round(sum(case when has_discount = 1 then 1 else 0 end) * 100.0 / count(*), 2)
      else 0
    end as discount_penetration_percentage,

    case
      when sum(gross_amount) > 0
        then round(sum(discount_amount) / sum(gross_amount) * 100, 2)
      else 0
    end as overall_discount_percentage,

    -- Order complexity metrics
    case
      when count(*) = 1 then 'SINGLE_LINE'
      when count(*) <= 5 then 'SIMPLE_ORDER'
      when count(*) <= 15 then 'COMPLEX_ORDER'
      else 'VERY_COMPLEX_ORDER'
    end as order_complexity,

    case
      when count(distinct category_name) = 1 then 'SINGLE_CATEGORY'
      when count(distinct category_name) <= 3 then 'MULTI_CATEGORY'
      else 'DIVERSE_ORDER'
    end as category_diversity,

    -- Order value categorization  
    case
      when sum(line_total) < 500 then 'SMALL_ORDER'
      when sum(line_total) < 2500 then 'MEDIUM_ORDER'
      when sum(line_total) < 10000 then 'LARGE_ORDER'
      else 'ENTERPRISE_ORDER'
    end as order_value_tier,

    -- Seasonal information
    min(order_year) as order_year,
    min(order_month) as order_month,
    min(order_quarter) as order_quarter,
    min(order_day_of_week) as order_day_of_week,
    min(order_season) as order_season,

    -- Metadata
    min(source_modified_date) as source_modified_date,
    min(silver_created_at) as source_silver_created_at,
    getdate() as order_summary_created_at

  from sales_details

  group by
    sales_order_id,
    sales_order_number,
    purchase_order_number

    -- Data quality filters
  having
    count(*) > 0
    and sum(line_total) > 0
)

select * from order_aggregation