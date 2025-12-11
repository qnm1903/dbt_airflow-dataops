{{ config(materialized='table') }}

-- Gold layer: Comprehensive customer analytics and business metrics
-- Business-ready mart for customer performance analysis and segmentation

-- Gold layer: Comprehensive customer analytics and business metrics
-- Business-ready mart for customer performance analysis and segmentation
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

customer_item_metrics as (
  select
    customer_id,
    count(*) as total_line_items,
    count(distinct product_id) as unique_products_purchased,
    count(distinct category_name) as unique_categories_purchased
  from sales_details
  group by customer_id
),

customer_order_metrics as (
  select
    customer_id,
    min(order_date) as first_order_date,
    max(order_date) as last_order_date,
    count(distinct sales_order_id) as total_orders,
    sum(total_order_value) as lifetime_revenue,
    avg(total_order_value) as avg_order_value,
    0 as median_order_value,
    min(total_order_value) as min_order_value,
    max(total_order_value) as max_order_value,
    stdev(total_order_value) as order_value_std_dev,
    sum(total_quantity) as total_items_purchased,
    avg(total_quantity) as avg_items_per_order,
    sum(total_discount_amount) as total_discounts_received,
    avg(overall_discount_percentage) as avg_discount_percentage,
    sum(case when overall_discount_percentage > 0 then 1 else 0 end) as orders_with_discounts,
    sum(case when order_channel = 'Online' then 1 else 0 end) as online_orders,
    sum(case when order_channel = 'Offline' then 1 else 0 end) as offline_orders,
    avg(total_line_items * 1.0) as avg_lines_per_order,
    avg(unique_products * 1.0) as avg_unique_products_per_order,
    sum(case when days_early_late <= 0 then 1 else 0 end) as on_time_orders,
    sum(case when order_status = 5 then 1 else 0 end) as completed_orders,
    sum(case when order_status = 6 then 1 else 0 end) as cancelled_orders
  from order_summary
  group by customer_id
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
    datediff(day, o.last_order_date, cast(getdate() as DATE)) as days_since_last_order,

    -- Metrics from Item Aggregation
    coalesce(i.total_line_items, 0) as total_line_items,
    coalesce(i.unique_products_purchased, 0) as unique_products_purchased,
    coalesce(i.unique_categories_purchased, 0) as unique_categories_purchased

  from customers as c
  left join customer_order_metrics as o
    on c.customer_id = o.customer_id
  left join customer_item_metrics as i
    on c.customer_id = i.customer_id
),

-- Customer segmentation and business intelligence
customer_analytics as (
  select
    *,
    -- Customer Segmentation based on Lifetime Revenue
    case
        when lifetime_revenue >= 5000 then 'VIP'
        when lifetime_revenue >= 2500 then 'HIGH_VALUE'
        when lifetime_revenue >= 1000 then 'MEDIUM_VALUE'
        when lifetime_revenue > 0 then 'LOW_VALUE'
        else 'ONE_TIME_BUYER' -- Fallback for very low or single purchase
    end as customer_value_segment,

    -- Customer Lifecycle Stage based on recency
    case
        when days_since_last_order <= 90 then 'ACTIVE'
        when days_since_last_order <= 180 then 'AT_RISK'
        when days_since_last_order <= 365 then 'LAPSED'
        when days_since_last_order > 365 then 'CHURNED'
        else 'PROSPECT' -- No orders
    end as lifecycle_stage,

    -- RFM Scores (Simplified Logic for Demo)
    case when days_since_last_order <= 30 then 5
         when days_since_last_order <= 90 then 4
         when days_since_last_order <= 180 then 3
         when days_since_last_order <= 365 then 2
         else 1 end as recency_score,
    
    case when total_orders >= 20 then 5
         when total_orders >= 10 then 4
         when total_orders >= 5 then 3
         when total_orders >= 2 then 2
         else 1 end as frequency_score,

    case when lifetime_revenue >= 5000 then 5
         when lifetime_revenue >= 2500 then 4
         when lifetime_revenue >= 1000 then 3
         when lifetime_revenue >= 500 then 2
         else 1 end as monetary_score,

    -- Channel Preference
    case 
        when online_orders > 0 and offline_orders = 0 then 'ONLINE_ONLY'
        when offline_orders > 0 and online_orders = 0 then 'OFFLINE_ONLY'
        when online_orders > 0 and offline_orders > 0 then 'OMNICHANNEL'
        else 'NO_ORDERS'
    end as channel_preference,
    
    getdate() as gold_created_at

  from customer_transaction_metrics
)

select * from customer_analytics
