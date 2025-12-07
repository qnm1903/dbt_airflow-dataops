{{ config(materialized='view') }}

-- Bronze layer: Raw data cleaning and standardization for customers
with customers_raw as (
  select * from {{ source('adventureworks', 'Customer') }}
),

person_raw as (
  select * from {{ source('person', 'Person') }}
),

cleaned as (
  select
    -- Primary identifiers
    c.CustomerID as customer_id,
    c.PersonID as person_id,

    -- Personal information with cleaning
    c.StoreID as store_id,
    c.TerritoryID as territory_id,
    c.ModifiedDate as source_modified_date,

    -- Business identifiers
    LTRIM(RTRIM(UPPER(coalesce(p.FirstName, 'UNKNOWN')))) as first_name,
    LTRIM(RTRIM(UPPER(coalesce(p.LastName, 'UNKNOWN')))) as last_name,

    -- Metadata
    coalesce(p.EmailPromotion, 0) as email_promotion,
    GETDATE() as bronze_created_at

  from customers_raw as c
  left join person_raw as p
    on c.PersonID = p.BusinessEntityID

    -- Data quality filters
  where c.CustomerID is not null
)

select * from cleaned