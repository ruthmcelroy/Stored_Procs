with source as (
    select * from {{ ref('config_param') }}
),

renamed as (
    select
        paramkey::varchar as param_key,
        paramvalue::varchar as param_value,
        paramtype::varchar as param_type
    from source
)

select * from renamed
