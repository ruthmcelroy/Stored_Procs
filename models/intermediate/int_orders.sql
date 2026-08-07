with order_lines as (
    select * from {{ ref('int_order_lines') }}
),

aggregated as (
    select
        external_order_ref,
        max(order_date) as order_date,
        max(customer_id) as customer_id,
        max(currency_code) as currency_code,
        count(*) as order_line_count,
        sum(gross_revenue) as gross_revenue,
        sum(line_discount) as discount_total,
        sum(net_revenue) as net_revenue
    from order_lines
    group by 1
)

select * from aggregated
