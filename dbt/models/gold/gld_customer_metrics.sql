{{ config(materialized='table') }}

-- Gold layer: Comprehensive customer analytics and business metrics
-- Business-ready mart for customer performance analysis and segmentation

with customers as (
  select * from {{ ref('slvr_customers') }}
),

order_summary as (
  select * from {{ ref('slvr_order_summary') }}
),

sales_details as (
  select * from {{ ref('slvr_sales_orders') }}
),

products as (
  select * from {{ ref('slvr_products') }}
),

customer_transaction_metrics as (
  select
    c.customer_id,
    c.full_name,
    c.customer_type,
    c.email_preference_category,
    c.territory_id,
    c.is_store_customer,

    -- Metrics from Order Aggregation
    o.first_order_date,
    o.last_order_date,
    coalesce(o.total_orders, 0) as total_orders,
    coalesce(o.lifetime_revenue, 0) as lifetime_revenue,
    coalesce(o.avg_order_value, 0) as avg_order_value,
    coalesce(o.median_order_value, 0) as median_order_value,
    coalesce(o.min_order_value, 0) as min_order_value,
    coalesce(o.max_order_value, 0) as max_order_value,
    coalesce(o.order_value_std_dev, 0) as order_value_std_dev,
    coalesce(o.total_items_purchased, 0) as total_items_purchased,
    coalesce(o.avg_items_per_order, 0) as avg_items_per_order,
    coalesce(o.total_discounts_received, 0) as total_discounts_received,
    coalesce(o.avg_discount_percentage, 0) as avg_discount_percentage,
    coalesce(o.orders_with_discounts, 0) as orders_with_discounts,
    coalesce(o.online_orders, 0) as online_orders,
    coalesce(o.offline_orders, 0) as offline_orders,
    coalesce(o.avg_lines_per_order, 0) as avg_lines_per_order,
    coalesce(o.avg_unique_products_per_order, 0) as avg_unique_products_per_order,
    coalesce(o.on_time_orders, 0) as on_time_orders,
    coalesce(o.completed_orders, 0) as completed_orders,
    coalesce(o.cancelled_orders, 0) as cancelled_orders,

    -- Derived Date Logic
    datediff(day, o.first_order_date, o.last_order_date) as customer_tenure_days,
    datediff(day, o.last_order_date, CAST(getdate() AS DATE)) as days_since_last_order,

    -- Metrics from Item Aggregation
    coalesce(i.total_line_items, 0) as total_line_items,
    coalesce(i.unique_products_purchased, 0) as unique_products_purchased,
    coalesce(i.unique_categories_purchased, 0) as unique_categories_purchased

  from customers AS c
  left join customer_order_metrics AS o
    on c.customer_id = o.customer_id
  left join customer_item_metrics AS i
    on c.customer_id = i.customer_id
),

-- Customer segmentation and business intelligence
customer_analytics as (
  select
    *,
    getdate() as gold_created_at

  from customer_transaction_metrics
)

select * from customer_analytics
