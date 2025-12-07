{{ config(materialized='table') }}

-- Silver layer: Enhanced sales order data with business logic and enriched metrics
with bronze_sales as (
  select * from {{ ref('brnz_sales_orders') }}
),

bronze_customers as (
  select * from {{ ref('brnz_customers') }}
),

bronze_products as (
  select * from {{ ref('brnz_products') }}
),

sales_enrichment as (
  select
    -- Primary identifiers
    s.sales_order_id,
    s.sales_order_detail_id,
    s.sales_order_number,
    s.purchase_order_number,

    -- Date analysis with business logic
    s.order_date,
    s.due_date,
    s.ship_date,

    -- Order timing analysis
    s.order_status,

    s.online_order_flag,

    s.customer_id,

    -- Order performance categorization
    s.sales_person_id,

    -- Status and channel
    s.territory_id,
    s.product_id,

    p.product_name,
    p.category_name,

    -- Customer and territory information
    p.subcategory_name,
    s.order_quantity,
    s.unit_price,
    s.unit_price_discount,

    -- Product information with enrichment
    s.line_total,
    s.source_modified_date,
    s.bronze_created_at,
    case
      when s.due_date is not null and s.order_date is not null
        then datediff(day, s.order_date, s.due_date)
    end as days_to_due,

    -- Quantity and pricing with business calculations
    case
      when s.ship_date is not null and s.order_date is not null
        then datediff(day, s.order_date, s.ship_date)
    end as days_to_ship,
    case
      when s.ship_date is not null and s.due_date is not null
        then datediff(day, s.due_date, s.ship_date)
    end as days_early_late,
    case
      when s.ship_date is null then 'NOT_SHIPPED'
      when s.ship_date <= s.due_date then 'ON_TIME'
      when datediff(day, s.due_date, s.ship_date) <= 3 then 'SLIGHTLY_LATE'
      else 'SIGNIFICANTLY_LATE'
    end as delivery_performance,
    case
      when s.order_status = 1 then 'IN_PROCESS'
      when s.order_status = 2 then 'APPROVED'
      when s.order_status = 3 then 'BACKORDERED'
      when s.order_status = 4 then 'REJECTED'
      when s.order_status = 5 then 'SHIPPED'
      when s.order_status = 6 then 'CANCELLED'
      else 'UNKNOWN_STATUS'
    end as order_status_description,

    -- Calculated financial metrics
    case
      when s.online_order_flag = 1 then 'ONLINE'
      else 'OFFLINE'
    end as order_channel,
    case
      when c.person_id is null then 'BUSINESS'
      else 'INDIVIDUAL'
    end as customer_type,
    s.unit_price * s.order_quantity as gross_amount,

    -- Discount analysis
    s.unit_price * s.order_quantity * s.unit_price_discount as discount_amount,

    case
      when s.order_quantity > 0
        then s.line_total / s.order_quantity
      else 0
    end as effective_unit_price,

    -- Order size categorization
    case
      when s.unit_price_discount > 0 then 1
      else 0
    end as has_discount,

    -- Revenue categorization
    case
      when s.unit_price_discount = 0 then 'NO_DISCOUNT'
      when s.unit_price_discount <= 0.05 then 'SMALL_DISCOUNT'
      when s.unit_price_discount <= 0.15 then 'MEDIUM_DISCOUNT'
      else 'LARGE_DISCOUNT'
    end as discount_category,

    -- Seasonal analysis
    case
      when s.order_quantity = 1 then 'SINGLE_ITEM'
      when s.order_quantity <= 5 then 'SMALL_ORDER'
      when s.order_quantity <= 20 then 'MEDIUM_ORDER'
      else 'LARGE_ORDER'
    end as order_size_category,
    case
      when s.line_total < 100 then 'LOW_VALUE'
      when s.line_total < 1000 then 'MEDIUM_VALUE'
      when s.line_total < 5000 then 'HIGH_VALUE'
      else 'PREMIUM_VALUE'
    end as revenue_category,
    year(s.order_date) as order_year,
    month(s.order_date) as order_month,

    datepart(quarter, s.order_date) as order_quarter,

    -- Metadata
    datename(weekday, s.order_date) as order_day_of_week,
    case
      when month(s.order_date) in (12, 1, 2) then 'WINTER'
      when month(s.order_date) in (3, 4, 5) then 'SPRING'
      when month(s.order_date) in (6, 7, 8) then 'SUMMER'
      else 'FALL'
    end as order_season,
    getdate() as silver_created_at

  from bronze_sales as s
  left join bronze_customers as c
    on s.customer_id = c.customer_id
  left join bronze_products as p
    on s.product_id = p.product_id

    -- Data quality filters for silver layer
  where
    s.sales_order_id is not null
    and s.sales_order_detail_id is not null
    and s.order_quantity > 0
    and s.line_total >= 0
)

select * from sales_enrichment
