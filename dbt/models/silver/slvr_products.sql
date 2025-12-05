{{ config(materialized='table') }}

-- Silver layer: Enhanced product data with business logic and product categorization
with bronze_products as (
    select * from {{ ref('brnz_products') }}
),

product_enrichment as (
    select
        -- Primary identifiers
        product_id,
        product_number,
        product_name,
        
        -- Product attributes with business logic
        case when color = 'NOT SPECIFIED' then 'N/A' else color end as color,
        case when p_size = 'NOT SPECIFIED' then 'N/A' else p_size end as p_size,
        case 
            when color = 'NOT SPECIFIED' and p_size = 'NOT SPECIFIED' 
            then 'STANDARD_ITEM'
            else 'CUSTOMIZED_ITEM'
        end as customization_level,
        
        -- Manufacturing and sourcing
        make_flag,
        finished_goods_flag,
        case 
            when make_flag = 1 then 'MANUFACTURED'
            else 'PURCHASED'
        end as sourcing_type,
        
        case 
            when finished_goods_flag = 1 then 'SELLABLE'
            else 'COMPONENT_ONLY'
        end as sellability_status,
        
        -- Financial metrics with business calculations
        standard_cost,
        list_price,
        case 
            when list_price > 0 and standard_cost > 0
            then round((list_price - standard_cost) / list_price * 100, 2)
            else 0
        end as profit_margin_percentage,
        
        case 
            when list_price > 0 and standard_cost > 0
            then list_price - standard_cost
            else 0
        end as profit_per_unit,
        
        -- Price categorization
        case 
            when list_price = 0 then 'NO_PRICE'
            when list_price < 50 then 'LOW_PRICE'
            when list_price < 500 then 'MEDIUM_PRICE'
            when list_price < 2000 then 'HIGH_PRICE'
            else 'PREMIUM_PRICE'
        end as price_category,
        
        -- Inventory management
        safety_stock_level,
        reorder_point,
        case 
            when safety_stock_level > 0 or reorder_point > 0 then 'INVENTORY_MANAGED'
            else 'NO_INVENTORY_TRACKING'
        end as inventory_status,
        
        -- Physical properties
        weight,
        case 
            when weight is null then 'WEIGHT_NOT_SPECIFIED'
            when weight < 1 then 'LIGHTWEIGHT'
            when weight < 10 then 'MEDIUM_WEIGHT'
            else 'HEAVYWEIGHT'
        end as weight_category,
        
        -- Manufacturing metrics
        days_to_manufacture,
        case 
            when days_to_manufacture = 0 then 'IMMEDIATE'
            when days_to_manufacture <= 5 then 'FAST_PRODUCTION'
            when days_to_manufacture <= 15 then 'STANDARD_PRODUCTION'
            else 'SLOW_PRODUCTION'
        end as manufacturing_speed,
        
        -- Product hierarchy
        category_name,
        subcategory_name,
        
        -- Product lifecycle
        sell_start_date,
        sell_end_date,
        case 
            when sell_end_date is null then 'ACTIVE'
            when sell_end_date > CAST(GETDATE() AS DATE) then 'ACTIVE'
            else 'DISCONTINUED'
        end as product_status,
        
        -- Date calculations
        case 
            when sell_start_date is not null 
            then datediff(day, sell_start_date, coalesce(sell_end_date, CAST(GETDATE() AS DATE)))
            else null
        end as days_in_market,
        
        -- Metadata
        source_modified_date,
        bronze_created_at,
        GETDATE() as silver_created_at
        
    from bronze_products
    
    -- Data quality filters for silver layer
    where product_id is not null
        and product_name != 'Unknown Product'
)

select * from product_enrichment
