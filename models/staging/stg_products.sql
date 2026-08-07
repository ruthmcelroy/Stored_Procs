with source as (
    select * from {{ ref('product') }}
),

renamed as (
    select
        productid::integer as product_id,
        sku::varchar as sku,
        productname::varchar as product_name,
        categoryid::integer as category_id,
        supplierid::integer as supplier_id,
        unitcost::number(18, 4) as unit_cost,
        listprice::number(18, 4) as list_price,
        status::varchar as product_status
    from source
)

select * from renamed
