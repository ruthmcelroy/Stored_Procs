with source as (
    select * from {{ ref('supplier') }}
),

renamed as (
    select
        supplierid::integer as supplier_id,
        suppliername::varchar as supplier_name,
        countrycode::varchar as country_code,
        leadtimedays::integer as lead_time_days,
        isactive::boolean as is_active
    from source
)

select * from renamed
