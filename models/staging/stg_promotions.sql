with source as (
    select * from {{ ref('promotion') }}
),

renamed as (
    select
        promotionid::integer as promotion_id,
        promocode::varchar as promo_code,
        promotype::varchar as promo_type,
        discountpct::number(18, 4) as discount_pct,
        discountamt::number(18, 4) as discount_amt,
        minspend::number(18, 4) as min_spend,
        categoryid::integer as category_id,
        effectivefrom::date as effective_from,
        effectiveto::date as effective_to,
        maxredemptions::integer as max_redemptions,
        isactive::boolean as is_active
    from source
)

select * from renamed
