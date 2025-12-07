{{ config(materialized='table') }}

-- Gold layer: Comprehensive sales analytics and business intelligence dashboard
-- Business-ready mart for sales performance analysis, trends, and forecasting
with sales_details as (
  select * from {{ ref('slvr_sales_orders') }}
),

order_summary as (
  select * from {{ ref('slvr_order_summary') }}
),

-- Daily sales metrics aggregation
daily_sales_metrics as (
  select
    cast(s.order_date as date) as sale_date,
    s.order_day_of_week,
    s.order_season,
    year(s.order_date) as sale_year,
    month(s.order_date) as sale_month,
    datepart(quarter, s.order_date) as sale_quarter,

    -- Order volume metrics
    count(distinct s.sales_order_id) as total_orders,
    count(distinct s.sales_order_detail_id) as total_line_items,
    count(distinct s.customer_id) as unique_customers,
    count(distinct s.product_id) as unique_products_sold,
    count(distinct s.category_name) as unique_categories_sold,

    -- Financial performance
    sum(s.line_total) as total_revenue,
    sum(s.gross_amount) as total_gross_revenue,
    sum(s.discount_amount) as total_discount_amount,
    avg(s.line_total) as avg_line_value,
    min(s.line_total) as min_line_value,
    max(s.line_total) as max_line_value,
    stdev(s.line_total) as line_value_std_dev,

    -- Quantity metrics
    sum(s.order_quantity) as total_items_sold,
    avg(s.order_quantity) as avg_items_per_line,

    -- Channel analysis
    sum(case when s.order_channel = 'ONLINE' then s.line_total else 0 end) as online_revenue,
    sum(case when s.order_channel = 'OFFLINE' then s.line_total else 0 end) as offline_revenue,
    count(case when s.order_channel = 'ONLINE' then 1 end) as online_orders,
    count(case when s.order_channel = 'OFFLINE' then 1 end) as offline_orders,

    -- Customer type analysis
    sum(case when s.customer_type = 'BUSINESS' then s.line_total else 0 end) as business_revenue,
    sum(case when s.customer_type = 'INDIVIDUAL' then s.line_total else 0 end) as individual_revenue,
    count(case when s.customer_type = 'BUSINESS' then 1 end) as business_orders,
    count(case when s.customer_type = 'INDIVIDUAL' then 1 end) as individual_orders,

    -- Discount analysis
    count(case when s.has_discount = 1 then 1 end) as discounted_lines,
    sum(case when s.has_discount = 1 then s.line_total else 0 end) as discounted_revenue,
    avg(case when s.has_discount = 1 then s.unit_price_discount else 0 end) as avg_discount_rate,

    -- Order size distribution
    count(case when s.order_size_category = 'SINGLE_ITEM' then 1 end) as single_item_lines,
    count(case when s.order_size_category = 'SMALL_ORDER' then 1 end) as small_order_lines,
    count(case when s.order_size_category = 'MEDIUM_ORDER' then 1 end) as medium_order_lines,
    count(case when s.order_size_category = 'LARGE_ORDER' then 1 end) as large_order_lines,

    -- Revenue distribution  
    count(case when s.revenue_category = 'LOW_VALUE' then 1 end) as low_value_lines,
    count(case when s.revenue_category = 'MEDIUM_VALUE' then 1 end) as medium_value_lines,
    count(case when s.revenue_category = 'HIGH_VALUE' then 1 end) as high_value_lines,
    count(case when s.revenue_category = 'PREMIUM_VALUE' then 1 end) as premium_value_lines,

    -- Order status analysis
    count(case when s.order_status_description = 'SHIPPED' then 1 end) as shipped_lines,
    count(case when s.order_status_description = 'CANCELLED' then 1 end) as cancelled_lines,
    count(case when s.order_status_description = 'IN_PROCESS' then 1 end) as processing_lines,

    -- Performance metrics
    count(case when s.delivery_performance = 'ON_TIME' then 1 end) as on_time_lines,
    count(case when s.delivery_performance = 'SLIGHTLY_LATE' then 1 end) as slightly_late_lines,
    count(case when s.delivery_performance = 'SIGNIFICANTLY_LATE' then 1 end) as significantly_late_lines,
    avg(s.days_to_ship) as avg_days_to_ship,
    avg(s.days_early_late) as avg_days_early_late

  from sales_details as s

  group by
    cast(s.order_date as date), year(s.order_date), month(s.order_date),
    datepart(quarter, s.order_date), s.order_day_of_week, s.order_season
),

-- Enhanced daily analytics with business intelligence
daily_analytics as (
  select
    *,

    -- Growth metrics (compared to previous periods)
    lag(total_revenue, 1) over (order by sale_date) as prev_day_revenue,
    lag(total_orders, 1) over (order by sale_date) as prev_day_orders,
    lag(unique_customers, 1) over (order by sale_date) as prev_day_customers,

    -- Moving averages for trend analysis
    avg(total_revenue) over (
      order by sale_date
      rows between 6 preceding and current row
    ) as revenue_7day_avg,

    avg(total_revenue) over (
      order by sale_date
      rows between 29 preceding and current row
    ) as revenue_30day_avg,

    avg(total_orders) over (
      order by sale_date
      rows between 6 preceding and current row
    ) as orders_7day_avg,

    -- Performance ratios and KPIs
    case
      when total_orders > 0
        then total_revenue / total_orders
      else 0
    end as average_order_value,

    case
      when unique_customers > 0
        then total_revenue / unique_customers
      else 0
    end as revenue_per_customer,

    case
      when total_line_items > 0
        then (discounted_lines * 100.0 / total_line_items)
      else 0
    end as discount_penetration_rate,

    case
      when total_gross_revenue > 0
        then (total_discount_amount / total_gross_revenue * 100)
      else 0
    end as discount_impact_percentage,

    case
      when total_revenue > 0
        then (online_revenue / total_revenue * 100)
      else 0
    end as online_revenue_percentage,

    case
      when total_orders > 0
        then (online_orders * 100.0 / total_orders)
      else 0
    end as online_order_percentage,

    case
      when total_revenue > 0
        then (business_revenue / total_revenue * 100)
      else 0
    end as business_revenue_percentage,

    case
      when total_line_items > 0
        then (on_time_lines * 100.0 / total_line_items)
      else 0
    end as on_time_delivery_percentage,

    -- Market dynamics
    case
      when total_orders > 0
        then cast(unique_customers as float) / total_orders
      else 0
    end as customer_order_ratio,

    case
      when unique_customers > 0
        then cast(total_line_items as float) / unique_customers
      else 0
    end as lines_per_customer,

    case
      when total_orders > 0
        then cast(total_line_items as float) / total_orders
      else 0
    end as lines_per_order,

    -- Day-of-week patterns
    case
      when order_day_of_week in ('Saturday', 'Sunday') then 'WEEKEND'
      else 'WEEKDAY'
    end as day_type,

    -- Business classification
    case
      when total_revenue >= 50000 then 'HIGH_VOLUME_DAY'
      when total_revenue >= 20000 then 'GOOD_VOLUME_DAY'
      when total_revenue >= 5000 then 'NORMAL_VOLUME_DAY'
      when total_revenue > 0 then 'LOW_VOLUME_DAY'
      else 'NO_SALES_DAY'
    end as sales_volume_category,

    -- Seasonal performance indicators
    row_number() over (
      partition by sale_year, order_season
      order by total_revenue desc
    ) as seasonal_revenue_rank,

    row_number() over (
      partition by sale_year, sale_month
      order by total_revenue desc
    ) as monthly_revenue_rank,

    -- Timestamp
    getdate() as gold_created_at

  from daily_sales_metrics
)

select * from daily_analytics
