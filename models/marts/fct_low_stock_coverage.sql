{{ config(materialized='table') }}

with inventory as (
    select * from {{ ref('int_inventory_availability') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

suppliers as (
    select * from {{ ref('stg_suppliers') }}
)

select
    inventory.warehouse_id,
    inventory.product_id,
    products.sku,
    products.product_name,
    products.supplier_id,
    suppliers.supplier_name,
    inventory.qty_available,
    inventory.qty_on_order as on_order_quantity,
    inventory.reorder_point,
    inventory.reorder_qty,
    inventory.qty_available + inventory.qty_on_order as projected_available_quantity
from inventory
inner join products using (product_id)
left join suppliers using (supplier_id)
where inventory.is_below_reorder
