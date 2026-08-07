with source as (
    select * from {{ ref('stock_level') }}
),

renamed as (
    select
        warehouseid::integer as warehouse_id,
        productid::integer as product_id,
        qtyonhand::integer as qty_on_hand,
        qtyallocated::integer as qty_allocated,
        qtyonorder::integer as qty_on_order,
        reorderpoint::integer as reorder_point,
        reorderqty::integer as reorder_qty
    from source
)

select * from renamed
