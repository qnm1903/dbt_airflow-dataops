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

-- Customer transaction metrics
customer_transaction_metrics as (
    select
        c.customer_id,
        c.full_name,
        c.customer_type,
        c.email_preference_category,
        c.territory_id,
        c.is_store_customer,
        
        -- Order volume metrics
        count(distinct o.sales_order_id) as total_orders,
        count(distinct s.sales_order_detail_id) as total_line_items,
        count(distinct s.product_id) as unique_products_purchased,
        count(distinct p.category_name) as unique_categories_purchased,
        
        -- Financial metrics
        coalesce(sum(o.total_order_value), 0) as lifetime_revenue,
        coalesce(avg(o.total_order_value), 0) as avg_order_value,
        -- Note: median approximated using avg for SQL Server compatibility
        coalesce(avg(o.total_order_value), 0) as median_order_value,
        coalesce(min(o.total_order_value), 0) as min_order_value,
        coalesce(max(o.total_order_value), 0) as max_order_value,
        coalesce(STDEV(o.total_order_value), 0) as order_value_std_dev,
        
        -- Quantity metrics
        coalesce(sum(o.total_quantity), 0) as total_items_purchased,
        coalesce(avg(o.total_quantity), 0) as avg_items_per_order,
        
        -- Discount behavior
        coalesce(sum(o.total_discount_amount), 0) as total_discounts_received,
        coalesce(avg(o.overall_discount_percentage), 0) as avg_discount_percentage,
        sum(case when o.total_discount_amount > 0 then 1 else 0 end) as orders_with_discounts,
        
        -- Order timing and recency
        min(o.order_date) as first_order_date,
        max(o.order_date) as last_order_date,
        datediff(day, min(o.order_date), max(o.order_date)) as customer_tenure_days,
        datediff(day, max(o.order_date), CAST(GETDATE() AS DATE)) as days_since_last_order,
        
        -- Channel preferences
        sum(case when o.order_channel = 'ONLINE' then 1 else 0 end) as online_orders,
        sum(case when o.order_channel = 'OFFLINE' then 1 else 0 end) as offline_orders,
        
        -- Order complexity
        avg(cast(o.total_line_items as float)) as avg_lines_per_order,
        avg(cast(o.unique_products as float)) as avg_unique_products_per_order,
        
        -- Performance metrics
        sum(case when o.delivery_performance = 'ON_TIME' then 1 else 0 end) as on_time_orders,
        sum(case when o.order_status_description = 'SHIPPED' then 1 else 0 end) as completed_orders,
        sum(case when o.order_status_description = 'CANCELLED' then 1 else 0 end) as cancelled_orders
        
    from customers c
    left join order_summary o
        on c.customer_id = o.customer_id
    left join sales_details s
        on c.customer_id = s.customer_id
    left join products p
        on s.product_id = p.product_id
    
    group by 
        c.customer_id, c.full_name, c.customer_type, 
        c.email_preference_category, c.territory_id, c.is_store_customer
),

-- Customer segmentation and business intelligence
customer_analytics as (
    select
        *,
        
        -- RFM Analysis components
        case 
            when days_since_last_order <= 30 then 5
            when days_since_last_order <= 90 then 4
            when days_since_last_order <= 180 then 3
            when days_since_last_order <= 365 then 2
            else 1
        end as recency_score,
        
        case 
            when total_orders >= 20 then 5
            when total_orders >= 10 then 4
            when total_orders >= 5 then 3
            when total_orders >= 2 then 2
            else 1
        end as frequency_score,
        
        case 
            when lifetime_revenue >= 10000 then 5
            when lifetime_revenue >= 5000 then 4
            when lifetime_revenue >= 2000 then 3
            when lifetime_revenue >= 500 then 2
            else 1
        end as monetary_score,
        
        -- Customer value segmentation
        case 
            when lifetime_revenue >= 10000 and total_orders >= 10 then 'VIP'
            when lifetime_revenue >= 5000 or total_orders >= 15 then 'HIGH_VALUE'
            when lifetime_revenue >= 1000 or total_orders >= 5 then 'MEDIUM_VALUE'
            when total_orders >= 2 then 'LOW_VALUE'
            else 'ONE_TIME_BUYER'
        end as customer_value_segment,
        
        -- Lifecycle stage
        case 
            when total_orders = 0 then 'PROSPECT'
            when total_orders = 1 and days_since_last_order > 365 then 'LAPSED'
            when days_since_last_order <= 90 then 'ACTIVE'
            when days_since_last_order <= 365 then 'AT_RISK'
            else 'CHURNED'
        end as lifecycle_stage,
        
        -- Purchase behavior patterns
        case 
            when online_orders > 0 and offline_orders = 0 then 'ONLINE_ONLY'
            when offline_orders > 0 and online_orders = 0 then 'OFFLINE_ONLY'
            when online_orders > 0 and offline_orders > 0 then 'OMNICHANNEL'
            else 'NO_ORDERS'
        end as channel_preference,
        
        -- Discount sensitivity
        case 
            when total_orders > 0 and (orders_with_discounts * 1.0 / total_orders) >= 0.8 then 'HIGH_DISCOUNT_SENSITIVITY'
            when total_orders > 0 and (orders_with_discounts * 1.0 / total_orders) >= 0.4 then 'MEDIUM_DISCOUNT_SENSITIVITY'
            when orders_with_discounts > 0 then 'LOW_DISCOUNT_SENSITIVITY'
            else 'NO_DISCOUNT_USAGE'
        end as discount_sensitivity,
        
        -- Order consistency
        case 
            when total_orders > 1 and order_value_std_dev / nullif(avg_order_value, 0) <= 0.3 then 'CONSISTENT_BUYER'
            when total_orders > 1 and order_value_std_dev / nullif(avg_order_value, 0) <= 0.7 then 'VARIABLE_BUYER'
            when total_orders > 1 then 'ERRATIC_BUYER'
            else 'INSUFFICIENT_DATA'
        end as purchase_consistency,
        
        -- Business metrics calculations
        case 
            when customer_tenure_days > 0 and total_orders > 1
            then lifetime_revenue / (customer_tenure_days / 365.0)
            else lifetime_revenue
        end as annual_revenue_rate,
        
        case 
            when customer_tenure_days > 0 and total_orders > 1
            then total_orders / (customer_tenure_days / 365.0) 
            else total_orders
        end as annual_order_frequency,
        
        -- Performance ratios
        case 
            when total_orders > 0 
            then (on_time_orders * 1.0 / total_orders) * 100
            else 0
        end as on_time_delivery_percentage,
        
        case 
            when total_orders > 0 
            then (completed_orders * 1.0 / total_orders) * 100
            else 0
        end as order_completion_rate,
        
        case 
            when total_orders > 0 
            then (cancelled_orders * 1.0 / total_orders) * 100
            else 0
        end as cancellation_rate,
        
        -- Timestamp
        GETDATE() as gold_created_at
        
    from customer_transaction_metrics
)

select * from customer_analytics
