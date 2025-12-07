{{ config(materialized='view') }}

-- Bronze layer: Raw data cleaning and standardization for sales orders
with header_raw as (
  select * from {{ source('adventureworks', 'SalesOrderHeader') }}
),

detail_raw as (
  select * from {{ source('adventureworks', 'SalesOrderDetail') }}
),

cleaned as (
  select
    -- Primary identifiers
    h.SalesOrderID as sales_order_id,
    d.SalesOrderDetailID as sales_order_detail_id,

    -- Order information
    h.OrderDate as order_date,
    h.DueDate as due_date,

    -- Dates with validation
    h.ShipDate as ship_date,
    h.CustomerID as customer_id,
    h.SalesPersonID as sales_person_id,

    -- Status and flags
    h.TerritoryID as territory_id,
    d.ProductID as product_id,

    -- Customer and territory
    h.ModifiedDate as source_modified_date,
    LTRIM(RTRIM(h.SalesOrderNumber)) as sales_order_number,
    LTRIM(RTRIM(h.PurchaseOrderNumber)) as purchase_order_number,

    -- Product and quantities
    coalesce(h.Status, 0) as order_status,
    coalesce(h.OnlineOrderFlag, 0) as online_order_flag,

    -- Financial data with validation
    case
      when d.OrderQty <= 0 then null
      else d.OrderQty
    end as order_quantity,
    case
      when d.UnitPrice < 0 then 0.0
      else coalesce(d.UnitPrice, 0.0)
    end as unit_price,
    case
      when d.UnitPriceDiscount < 0 or d.UnitPriceDiscount > 1 then 0.0
      else coalesce(d.UnitPriceDiscount, 0.0)
    end as unit_price_discount,

    -- Metadata
    case
      when d.LineTotal < 0 then 0.0
      else coalesce(d.LineTotal, 0.0)
    end as line_total,
    GETDATE() as bronze_created_at

  from header_raw as h
  inner join detail_raw as d
    on h.SalesOrderID = d.SalesOrderID

    -- Data quality filters
  where
    h.SalesOrderID is not null
    and d.SalesOrderDetailID is not null
    and h.OrderDate is not null
    and d.OrderQty > 0
    and d.UnitPrice >= 0
)

select * from cleaned