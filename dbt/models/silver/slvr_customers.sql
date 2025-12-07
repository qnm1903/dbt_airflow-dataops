{{ config(materialized='table') }}

-- Silver layer: Enhanced customer data with business logic and enrichment
with bronze_customers as (
  select * from {{ ref('brnz_customers') }}
),

customer_enrichment as (
  select
    customer_id,
    person_id,

    -- Name standardization and enrichment
    first_name,
    last_name,
    email_promotion,

    -- Customer segmentation
    store_id,

    -- Email marketing segmentation
    territory_id,
    source_modified_date,

    -- Business attributes
    bronze_created_at,
    case
      when first_name = 'UNKNOWN' and last_name = 'UNKNOWN'
        then 'BUSINESS_CUSTOMER'
      else concat(first_name, ' ', last_name)
    end as full_name,

    -- Flags for business logic
    case
      when person_id is null then 'BUSINESS'
      else 'INDIVIDUAL'
    end as customer_type,
    case
      when email_promotion = 0 then 'NO_EMAIL'
      when email_promotion = 1 then 'ADVENTURE_WORKS_ONLY'
      when email_promotion = 2 then 'PARTNER_EMAIL'
      else 'UNKNOWN'
    end as email_preference_category,
    case when store_id is not null then 1 else 0 end as is_store_customer,

    -- Metadata
    case when person_id is not null then 1 else 0 end as has_person_record,
    case when email_promotion > 0 then 1 else 0 end as accepts_email,
    getdate() as silver_created_at

  from bronze_customers

  -- Data quality filters for silver layer
  where customer_id is not null
)

select * from customer_enrichment
