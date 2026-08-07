with source as (
    select * from {{ ref('raw_order') }}
),

renamed as (
    select
        externalorderref::varchar as external_order_ref,
        customerno::varchar as customer_no,
        try_to_date(orderdatetext)::date as order_date,
        sku::varchar as sku,
        try_to_number(qty)::integer as quantity,
        try_to_decimal(unitpricetext, 18, 4) as unit_price,
        nullif(promocode::varchar, '') as promo_code,
        currencycode::varchar as currency_code,
        sourcesystem::varchar as source_system
    from source
)

select * from renamed
