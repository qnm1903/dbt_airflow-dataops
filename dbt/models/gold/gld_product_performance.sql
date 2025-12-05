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
        p.product_number,
        p.product_name,
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
        count(*) as total_line_items,
        sum(s.order_quantity) as total_quantity_sold,
        avg(s.order_quantity) as avg_quantity_per_order,
        min(s.order_quantity) as min_quantity_per_order,
        max(s.order_quantity) as max_quantity_per_order,
        
        -- Revenue and profitability
        sum(s.line_total) as total_revenue,
        avg(s.line_total) as avg_revenue_per_line,
        sum(s.gross_amount) as total_gross_revenue,
        sum(s.discount_amount) as total_discounts_given,
        avg(s.unit_price) as avg_selling_price,
        min(s.unit_price) as min_selling_price,
        max(s.unit_price) as max_selling_price,
        
        -- Actual profitability calculations
        sum(s.line_total) - (sum(s.order_quantity) * p.standard_cost) as total_actual_profit,
        case 
            when sum(s.line_total) > 0 
            then ((sum(s.line_total) - (sum(s.order_quantity) * p.standard_cost)) / sum(s.line_total)) * 100
            else 0
        end as actual_profit_margin_percentage,
        
        case 
            when sum(s.order_quantity) > 0 
            then (sum(s.line_total) - (sum(s.order_quantity) * p.standard_cost)) / sum(s.order_quantity)
            else 0
        end as actual_profit_per_unit,
        
        -- Discount analysis
        sum(case when s.has_discount = 1 then 1 else 0 end) as discounted_sales,
        case 
            when count(*) > 0 
            then (sum(case when s.has_discount = 1 then 1 else 0 end) * 100.0 / count(*))
            else 0
        end as discount_penetration_rate,
        
        avg(case when s.has_discount = 1 then s.unit_price_discount else 0 end) as avg_discount_rate,
        
        -- Temporal analysis
        min(s.order_date) as first_sale_date,
        max(s.order_date) as last_sale_date,
        datediff(day, min(s.order_date), max(s.order_date)) as days_in_sales,
        datediff(day, max(s.order_date), CAST(GETDATE() AS DATE)) as days_since_last_sale,
        
        -- Order value analysis
        sum(case when s.revenue_category = 'LOW_VALUE' then 1 else 0 end) as low_value_sales,
        sum(case when s.revenue_category = 'MEDIUM_VALUE' then 1 else 0 end) as medium_value_sales,
        sum(case when s.revenue_category = 'HIGH_VALUE' then 1 else 0 end) as high_value_sales,
        sum(case when s.revenue_category = 'PREMIUM_VALUE' then 1 else 0 end) as premium_value_sales,
        
        -- Channel analysis
        sum(case when s.order_channel = 'ONLINE' then s.line_total else 0 end) as online_revenue,
        sum(case when s.order_channel = 'OFFLINE' then s.line_total else 0 end) as offline_revenue,
        
        -- Seasonal performance
        sum(case when s.order_season = 'WINTER' then s.line_total else 0 end) as winter_revenue,
        sum(case when s.order_season = 'SPRING' then s.line_total else 0 end) as spring_revenue,
        sum(case when s.order_season = 'SUMMER' then s.line_total else 0 end) as summer_revenue,
        sum(case when s.order_season = 'FALL' then s.line_total else 0 end) as fall_revenue
        
    from products p
    left join sales_details s
        on p.product_id = s.product_id
    
    group by 
        p.product_id, p.product_number, p.product_name, p.category_name, p.subcategory_name,
        p.color, p.p_size, p.weight_category, p.price_category, p.sourcing_type, 
        p.sellability_status, p.product_status, p.manufacturing_speed,
        p.standard_cost, p.list_price, p.profit_margin_percentage, p.profit_per_unit
),

-- Product analytics and business intelligence
product_analytics as (
    select
        *,
        
        -- Performance rankings and percentiles
        row_number() over (order by total_revenue desc) as revenue_rank,
        row_number() over (order by total_quantity_sold desc) as quantity_rank,
        row_number() over (order by total_actual_profit desc) as profit_rank,
        row_number() over (order by unique_customers desc) as customer_reach_rank,
        
        -- Category performance comparisons
        case 
            when total_revenue > 0 then
                total_revenue / sum(total_revenue) over (partition by category_name) * 100
            else 0
        end as category_revenue_share,
        
        case 
            when total_quantity_sold > 0 then
                total_quantity_sold / sum(total_quantity_sold) over (partition by category_name) * 100
            else 0
        end as category_volume_share,
        
        -- Product lifecycle classification
        case 
            when total_orders = 0 then 'NO_SALES'
            when days_since_last_sale <= 30 then 'ACTIVE_SELLER'
            when days_since_last_sale <= 90 then 'SLOW_MOVING'
            when days_since_last_sale <= 365 then 'DECLINING'
            else 'DEAD_INVENTORY'
        end as sales_lifecycle_stage,
        
        -- Performance categorization
        case 
            when total_revenue >= 100000 and total_quantity_sold >= 1000 then 'STAR_PRODUCT'
            when total_revenue >= 50000 or total_quantity_sold >= 500 then 'HIGH_PERFORMER'
            when total_revenue >= 10000 or total_quantity_sold >= 100 then 'SOLID_PERFORMER'
            when total_orders > 0 then 'LOW_PERFORMER'
            else 'NO_SALES'
        end as performance_category,
        
        -- Profitability classification
        case 
            when actual_profit_margin_percentage >= 50 then 'HIGH_MARGIN'
            when actual_profit_margin_percentage >= 30 then 'GOOD_MARGIN'
            when actual_profit_margin_percentage >= 15 then 'ADEQUATE_MARGIN'
            when actual_profit_margin_percentage >= 0 then 'LOW_MARGIN'
            else 'LOSS_MAKING'
        end as profitability_tier,
        
        -- Pricing strategy insights
        case 
            when avg_selling_price > list_price * 1.05 then 'PREMIUM_PRICING'
            when avg_selling_price >= list_price * 0.95 then 'LIST_PRICE_SELLING'
            when avg_selling_price >= list_price * 0.8 then 'MODERATE_DISCOUNTING'
            else 'HEAVY_DISCOUNTING'
        end as pricing_strategy,
        
        -- Channel preference
        case 
            when total_revenue = 0 then 'NO_SALES'
            when online_revenue / total_revenue >= 0.8 then 'ONLINE_DOMINANT'
            when offline_revenue / total_revenue >= 0.8 then 'OFFLINE_DOMINANT'
            else 'BALANCED_CHANNEL'
        end as channel_preference,
        
        -- Seasonal pattern
        case 
            when total_revenue = 0 then 'NO_SALES'
            when (
                case 
                    when winter_revenue >= spring_revenue and winter_revenue >= summer_revenue and winter_revenue >= fall_revenue then winter_revenue
                    when spring_revenue >= summer_revenue and spring_revenue >= fall_revenue then spring_revenue
                    when summer_revenue >= fall_revenue then summer_revenue
                    else fall_revenue
                end
            ) / total_revenue >= 0.5 then 'SEASONAL'
            else 'NON_SEASONAL'
        end as seasonality_pattern,
        
        -- Customer appeal
        case 
            when total_orders > 0 and unique_customers > 0 then
                cast(unique_customers as float) / total_orders
            else 0
        end as customer_diversity_ratio,
        
        case 
            when unique_customers >= 100 then 'BROAD_APPEAL'
            when unique_customers >= 25 then 'MODERATE_APPEAL'
            when unique_customers >= 5 then 'NICHE_APPEAL'
            when unique_customers > 0 then 'LIMITED_APPEAL'
            else 'NO_APPEAL'
        end as market_appeal,
        
        -- Business intelligence metrics
        case 
            when days_in_sales > 0 and total_revenue > 0 
            then total_revenue / (days_in_sales / 365.0)
            else total_revenue
        end as annual_revenue_rate,
        
        case 
            when total_orders > 1 and days_in_sales > 0
            then total_orders / (days_in_sales / 365.0)
            else total_orders
        end as annual_sales_frequency,
        
        -- Timestamp
        GETDATE() as gold_created_at
        
    from product_sales_metrics
)

select * from product_analytics
