{{ config(materialized='table') }}

with inventory as (
    select * from {{ ref('int_inventory_availability') }}
)

select
    current_date() as snapshot_date,
    warehouse_id,
    product_id,
    qty_on_hand,
    qty_allocated,
    qty_available,
    qty_on_order,
    reorder_point,
    reorder_qty,
    stock_value,
    is_below_reorder
from inventory
