with source as (
    select * from {{ ref('customer') }}
),

renamed as (
    select
        customerid::integer as customer_id,
        customerno::varchar as customer_no,
        firstname::varchar as first_name,
        lastname::varchar as last_name,
        email::varchar as email,
        phone::varchar as phone,
        countrycode::varchar as country_code,
        status::varchar as customer_status
    from source
)

select * from renamed
