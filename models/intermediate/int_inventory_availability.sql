with stock_levels as (
    select * from {{ ref('stg_stock_levels') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

reorder_config as (
    select try_to_number(param_value)::integer as default_reorder_point
    from {{ ref('stg_config_params') }}
    where param_key = 'reorder.default.point'
),

inventory as (
    select
        stock_levels.warehouse_id,
        stock_levels.product_id,
        stock_levels.qty_on_hand,
        stock_levels.qty_allocated,
        stock_levels.qty_on_order,
        stock_levels.qty_on_hand - stock_levels.qty_allocated as qty_available,
        coalesce(stock_levels.reorder_point, reorder_config.default_reorder_point) as reorder_point,
        stock_levels.reorder_qty,
        round(stock_levels.qty_on_hand * coalesce(products.unit_cost, 0), 4) as stock_value
    from stock_levels
    inner join products using (product_id)
    cross join reorder_config
)

select
    *,
    qty_available + qty_on_order <= reorder_point as is_below_reorder
from inventory
