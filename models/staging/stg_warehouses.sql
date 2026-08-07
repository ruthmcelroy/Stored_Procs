with source as (
    select * from {{ ref('warehouse') }}
),

renamed as (
    select
        warehouseid::integer as warehouse_id,
        warehousecode::varchar as warehouse_code,
        warehousename::varchar as warehouse_name,
        countrycode::varchar as country_code,
        isactive::boolean as is_active
    from source
)

select * from renamed
