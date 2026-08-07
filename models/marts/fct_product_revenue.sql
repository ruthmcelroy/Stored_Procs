{{ config(materialized='table') }}

with order_lines as (
    select * from {{ ref('int_order_lines') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

aggregated as (
    select
        order_lines.product_id,
        products.sku,
        products.product_name,
        products.category_id,
        count(distinct order_lines.external_order_ref) as order_count,
        sum(order_lines.quantity) as units_sold,
        round(sum(order_lines.net_revenue), 4) as net_revenue
    from order_lines
    inner join products using (product_id)
    group by 1, 2, 3, 4
)

select * from aggregated
