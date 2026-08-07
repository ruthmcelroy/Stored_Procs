with raw_lines as (
    select * from {{ ref('stg_raw_order_lines') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

validated_lines as (
    select
        raw_lines.external_order_ref,
        raw_lines.order_date,
        raw_lines.customer_no,
        customers.customer_id,
        raw_lines.sku,
        products.product_id,
        products.category_id,
        products.unit_cost,
        raw_lines.quantity,
        raw_lines.unit_price,
        raw_lines.promo_code,
        raw_lines.currency_code,
        raw_lines.source_system,
        case
            when raw_lines.external_order_ref is null then false
            when raw_lines.order_date is null then false
            when customers.customer_id is null or customers.customer_status <> 'ACTIVE' then false
            when products.product_id is null or products.product_status <> 'ACTIVE' then false
            when raw_lines.quantity is null or raw_lines.quantity <= 0 then false
            when raw_lines.unit_price is null or raw_lines.unit_price < 0 then false
            else true
        end as is_valid_order_line
    from raw_lines
    left join customers on raw_lines.customer_no = customers.customer_no
    left join products on raw_lines.sku = products.sku
),

order_validation as (
    select
        external_order_ref,
        booland_agg(is_valid_order_line) as is_valid_order
    from validated_lines
    group by 1
),

valid_lines as (
    select
        validated_lines.*,
        row_number() over (
            partition by validated_lines.external_order_ref
            order by validated_lines.sku, validated_lines.unit_price, validated_lines.quantity
        ) as order_line_number,
        validated_lines.quantity * validated_lines.unit_price as gross_revenue
    from validated_lines
    inner join order_validation using (external_order_ref)
    where order_validation.is_valid_order
),

order_totals as (
    select
        external_order_ref,
        max(order_date) as order_date,
        max(customer_id) as customer_id,
        max(promo_code) as promo_code,
        sum(gross_revenue) as order_gross_revenue
    from valid_lines
    group by 1
),

promotion_candidates as (
    select
        order_totals.*,
        promotions.promo_type,
        promotions.discount_pct,
        promotions.discount_amt,
        promotions.category_id as promotion_category_id,
        case
            when promotions.promotion_id is null then false
            when not promotions.is_active then false
            when order_totals.order_date < promotions.effective_from then false
            when promotions.effective_to is not null and order_totals.order_date > promotions.effective_to then false
            when promotions.min_spend is not null and order_totals.order_gross_revenue < promotions.min_spend then false
            else true
        end as is_valid_promotion
    from order_totals
    left join {{ ref('stg_promotions') }} as promotions
        on order_totals.promo_code = promotions.promo_code
),

order_discounts as (
    select
        promotion_candidates.*,
        case
            when not is_valid_promotion then 0
            when promo_type = 'PCT' then order_gross_revenue * discount_pct / 100
            when promo_type = 'AMOUNT' then least(discount_amt, order_gross_revenue)
            else 0
        end as order_discount
    from promotion_candidates
),

allocated_discounts as (
    select
        valid_lines.*,
        order_discounts.order_discount,
        order_discounts.promo_type,
        order_discounts.discount_pct,
        order_discounts.promotion_category_id,
        order_discounts.is_valid_promotion,
        case
            when order_discounts.order_discount = 0 then 0
            when order_discounts.promo_type = 'PCT'
                and order_discounts.promotion_category_id is not null
                and valid_lines.category_id = order_discounts.promotion_category_id
                then valid_lines.gross_revenue * order_discounts.discount_pct / 100
            when order_discounts.promo_type = 'PCT' then valid_lines.gross_revenue * order_discounts.discount_pct / 100
            when order_discounts.promo_type = 'AMOUNT'
                then order_discounts.order_discount * valid_lines.gross_revenue / nullif(order_discounts.order_gross_revenue, 0)
            else 0
        end as line_discount
    from valid_lines
    inner join order_discounts using (external_order_ref)
)

select
    external_order_ref,
    order_line_number,
    order_date,
    customer_id,
    product_id,
    category_id,
    quantity,
    unit_price,
    gross_revenue,
    round(line_discount, 4) as line_discount,
    round(gross_revenue - line_discount, 4) as net_revenue,
    quantity * unit_cost as estimated_cost,
    currency_code,
    promo_code,
    is_valid_promotion,
    source_system
from allocated_discounts
