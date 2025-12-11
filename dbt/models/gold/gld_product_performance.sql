{{ config(materialized='table') }}

-- Gold layer: Comprehensive product performance analytics and business metrics  
-- Business-ready mart for product analysis, inventory optimization, and profitability insights

-- Gold layer: Comprehensive product performance analytics and business metrics  
-- Business-ready mart for product analysis, inventory optimization, and profitability insights
{{ config(materialized='table') }}

-- Gold layer: Comprehensive product performance analytics and business metrics  
-- Business-ready mart for product analysis, inventory optimization, and profitability insights
with products as (
  select * from {{ ref('slvr_products') }}
),

sales_details as (
  select * from {{ ref('slvr_sales_orders') }}
),

order_summary as (
  select * from {{ ref('slvr_order_summary') }}
),

-- Product sales performance metrics
product_sales_metrics as (
  select
    p.product_id,
    p.category_name,
    p.subcategory_name,
    p.color,
    p.p_size as size,
    p.weight_category,
    p.price_category,
    p.sourcing_type,
    p.sellability_status,
    p.product_status,
    p.manufacturing_speed,

    -- Pricing information
    p.standard_cost,
    p.list_price,
    p.profit_margin_percentage as list_profit_margin,
    p.profit_per_unit as list_profit_per_unit,

    -- Sales volume metrics
    count(distinct s.sales_order_id) as total_orders,
    count(distinct s.customer_id) as unique_customers,
    sum(case when s.sales_order_id is not null then 1 else 0 end) as total_line_items,
    coalesce(sum(s.order_quantity), 0) as total_quantity_sold,
    avg(s.order_quantity) as avg_quantity_per_order,
    min(s.order_quantity) as min_quantity_per_order,
    max(s.order_quantity) as max_quantity_per_order,

    -- Revenue and profitability
    coalesce(sum(s.line_total), 0) as total_revenue,
    avg(s.line_total) as avg_revenue_per_line,
    coalesce(sum(s.gross_amount), 0) as total_gross_revenue,
    coalesce(sum(s.discount_amount), 0) as total_discounts_given,
    avg(s.unit_price) as avg_selling_price,
    min(s.unit_price) as min_selling_price,
    max(s.unit_price) as max_selling_price,

    -- Actual profitability calculations
    coalesce(sum(s.line_total), 0) - (coalesce(sum(s.order_quantity), 0) * p.standard_cost) as total_actual_profit,
    case
      when coalesce(sum(s.line_total), 0) > 0
        then
          (
            (coalesce(sum(s.line_total), 0) - (coalesce(sum(s.order_quantity), 0) * p.standard_cost))
            / coalesce(sum(s.line_total), 0)
          )
          * 100
      else 0
    end as actual_profit_margin_percentage,

    case
      when coalesce(sum(s.order_quantity), 0) > 0
        then
          (coalesce(sum(s.line_total), 0) - (coalesce(sum(s.order_quantity), 0) * p.standard_cost))
          / coalesce(sum(s.order_quantity), 0)
      else 0
    end as actual_profit_per_unit,

    -- Discount analysis
    coalesce(sum(case when s.has_discount = 1 then 1 else 0 end), 0) as discounted_sales,
    case
      when sum(case when s.sales_order_id is not null then 1 else 0 end) > 0
        then
          (
            coalesce(sum(case when s.has_discount = 1 then 1 else 0 end), 0)
            / sum(case when s.sales_order_id is not null then 1 else 0 end)
          )
          * 100
      else 0
    end as discount_penetration_rate,

    avg(case when s.has_discount = 1 then s.unit_price_discount end) as avg_discount_rate,

    -- Temporal analysis
    min(s.order_date) as first_sale_date,
    max(s.order_date) as last_sale_date,
    case when min(s.order_date) is not null then datediff(day, min(s.order_date), max(s.order_date)) end
      as days_in_sales,
    case
      when max(s.order_date) is not null then datediff(day, max(s.order_date), cast(getdate() as DATE))
    end as days_since_last_sale,

    -- Order value analysis
    coalesce(sum(case when s.revenue_category = 'LOW_VALUE' then 1 else 0 end), 0) as low_value_sales

  from products p
  left join sales_details s
    on p.product_id = s.product_id

  group by
    p.product_id,
    p.category_name,
    p.subcategory_name,
    p.color,
    p.p_size,
    p.weight_category,
    p.price_category,
    p.sourcing_type,
    p.sellability_status,
    p.product_status,
    p.manufacturing_speed,
    p.standard_cost,
    p.list_price,
    p.profit_margin_percentage,
    p.profit_per_unit
),

-- Product analytics and business intelligence
product_analytics as (
  select *,
    -- Performance Category
    case
        when total_revenue >= 50000 then 'STAR_PRODUCT'
        when total_revenue >= 10000 then 'HIGH_PERFORMER'
        when total_revenue >= 5000 then 'SOLID_PERFORMER'
        when total_revenue > 0 then 'LOW_PERFORMER'
        else 'NO_SALES'
    end as performance_category,

    -- Sales Lifecycle Stage
    case
        when days_since_last_sale <= 30 then 'ACTIVE_SELLER'
        when days_since_last_sale <= 90 then 'SLOW_MOVING'
        when days_since_last_sale <= 180 then 'DECLINING'
        when days_since_last_sale > 180 then 'DEAD_INVENTORY'
        else 'NO_SALES'
    end as sales_lifecycle_stage,

    -- Profitability Tier
    case
        when actual_profit_margin_percentage >= 40 then 'HIGH_MARGIN'
        when actual_profit_margin_percentage >= 20 then 'GOOD_MARGIN'
        when actual_profit_margin_percentage >= 10 then 'ADEQUATE_MARGIN'
        when actual_profit_margin_percentage >= 0 then 'LOW_MARGIN'
        else 'LOSS_MAKING'
    end as profitability_tier,

    -- Market Appeal based on distinct customers
    case
        when unique_customers >= 100 then 'BROAD_APPEAL'
        when unique_customers >= 50 then 'MODERATE_APPEAL'
        when unique_customers >= 20 then 'NICHE_APPEAL'
        when unique_customers > 0 then 'LIMITED_APPEAL'
        else 'NO_APPEAL'
    end as market_appeal,
    
    -- Revenue Rank
    rank() over (order by total_revenue desc) as revenue_rank,

    getdate() as gold_created_at
  from product_sales_metrics
)

select * from product_analytics
