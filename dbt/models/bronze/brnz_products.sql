{{ config(materialized='view') }}

-- Bronze layer: Raw data cleaning and standardization for products
with products_raw as (
    select * from {{ source('production', 'Product') }}
),

subcategory_raw as (
    select * from {{ source('production', 'ProductSubcategory') }}
),

category_raw as (
    select * from {{ source('production', 'ProductCategory') }}
),

cleaned as (
    select
        -- Primary identifiers
        p.ProductID as product_id,
        LTRIM(RTRIM(p.ProductNumber)) as product_number,
        
        -- Product information with cleaning
        LTRIM(RTRIM(coalesce(p.Name, 'Unknown Product'))) as product_name,
        LTRIM(RTRIM(upper(coalesce(p.Color, 'NOT SPECIFIED')))) as color,
        LTRIM(RTRIM(upper(coalesce(p.Size, 'NOT SPECIFIED')))) as p_size,
        
        -- Flags and indicators
        coalesce(p.MakeFlag, 0) as make_flag,
        coalesce(p.FinishedGoodsFlag, 0) as finished_goods_flag,
        
        -- Financial data with validation
        case 
            when p.StandardCost < 0 then 0.0
            else coalesce(p.StandardCost, 0.0)
        end as standard_cost,
        case 
            when p.ListPrice < 0 then 0.0
            else coalesce(p.ListPrice, 0.0)
        end as list_price,
        
        -- Inventory data
        coalesce(p.SafetyStockLevel, 0) as safety_stock_level,
        coalesce(p.ReorderPoint, 0) as reorder_point,
        
        -- Physical properties
        p.Weight as weight,
        p.SizeUnitMeasureCode as size_unit_measure_code,
        p.WeightUnitMeasureCode as weight_unit_measure_code,
        
        -- Manufacturing
        coalesce(p.DaysToManufacture, 0) as days_to_manufacture,
        p.ProductLine as product_line,
        p.[Class] as class,
        p.[Style] as style,
        
        -- Hierarchy
        p.ProductSubcategoryID as product_subcategory_id,
        p.ProductModelID as product_model_id,
        LTRIM(RTRIM(coalesce(ps.Name, 'Uncategorized'))) as subcategory_name,
        ps.ProductCategoryID as product_category_id,
        LTRIM(RTRIM(coalesce(pc.Name, 'Uncategorized'))) as category_name,
        
        -- Dates
        p.SellStartDate as sell_start_date,
        p.SellEndDate as sell_end_date,
        p.DiscontinuedDate as discontinued_date,
        
        -- Metadata
        p.ModifiedDate as source_modified_date,
        GETDATE() as bronze_created_at
        
    from products_raw p
    left join subcategory_raw ps
        on p.ProductSubcategoryID = ps.ProductSubcategoryID
    left join category_raw pc
        on ps.ProductCategoryID = pc.ProductCategoryID
    
    -- Data quality filters
    where p.ProductID is not null
)

select * from cleaned 