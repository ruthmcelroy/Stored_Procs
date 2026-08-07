with orders as (
    select * from {{ ref('int_orders') }}
),

normalized_fx_rates as (
    select
        from_currency,
        to_currency,
        rate_date,
        rate
    from {{ ref('stg_fx_rates') }}

    union all

    select
        to_currency as from_currency,
        from_currency as to_currency,
        rate_date,
        1 / nullif(rate, 0) as rate
    from {{ ref('stg_fx_rates') }}
),

orders_with_rates as (
    select
        orders.*,
        fx_rates.rate as fx_rate_to_usd,
        row_number() over (
            partition by orders.external_order_ref
            order by fx_rates.rate_date desc nulls last
        ) as rate_rank
    from orders
    left join normalized_fx_rates as fx_rates
        on orders.currency_code = fx_rates.from_currency
        and fx_rates.to_currency = 'USD'
        and fx_rates.rate_date <= orders.order_date
)

select
    external_order_ref,
    order_date,
    customer_id,
    currency_code,
    order_line_count,
    gross_revenue,
    discount_total,
    net_revenue,
    coalesce(fx_rate_to_usd, 1) as fx_rate_to_usd,
    round(net_revenue * coalesce(fx_rate_to_usd, 1), 4) as net_revenue_usd,
    fx_rate_to_usd is null and currency_code <> 'USD' as is_fx_rate_fallback
from orders_with_rates
where rate_rank = 1
