{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('int_orders_with_usd') }}
),

aggregated as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        count(*) as order_count,
        round(sum(net_revenue_usd), 4) as total_net_spend_usd,
        boolor_agg(is_fx_rate_fallback) as has_fx_rate_fallback
    from orders
    group by 1
),

scored as (
    select
        *,
        round(total_net_spend_usd / nullif(order_count, 0), 4) as average_order_value_usd,
        round(
            total_net_spend_usd
            * case when datediff(day, last_order_date, current_date()) > 365 then 0.5 else 1 end,
            2
        ) as ltv_score,
        case
            when total_net_spend_usd >= 12000 then 'VIP'
            when datediff(day, last_order_date, current_date()) > 365 then 'LAPSED'
            when order_count = 1 then 'NEW'
            else 'REGULAR'
        end as ltv_segment
    from aggregated
)

select * from scored
