-- quantity must be a strictly positive number of items; the test fails if this query returns rows
select
    order_id,
    quantity
from {{ ref('stg_orders') }}
where quantity <= 0
