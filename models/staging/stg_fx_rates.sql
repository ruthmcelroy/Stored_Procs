with source as (
    select * from {{ ref('ref_fxrate') }}
),

renamed as (
    select
        fromcurrency::varchar as from_currency,
        tocurrency::varchar as to_currency,
        ratedate::date as rate_date,
        rate::number(18, 8) as rate
    from source
)

select * from renamed
