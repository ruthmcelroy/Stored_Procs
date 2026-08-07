{{ config(materialized='table') }}

with order_lines as (
    select * from {{ ref('int_order_lines') }}
),

aggregated as (
    select
        order_date as summary_date,
        category_id,
        count(distinct external_order_ref) as order_count,
        sum(quantity) as units_sold,
        round(sum(gross_revenue), 4) as gross_revenue,
        round(sum(line_discount), 4) as discount_total,
        round(sum(net_revenue), 4) as net_revenue,
        round(sum(net_revenue) - sum(estimated_cost), 4) as estimated_margin
    from order_lines
    group by 1, 2
)

select * from aggregated
