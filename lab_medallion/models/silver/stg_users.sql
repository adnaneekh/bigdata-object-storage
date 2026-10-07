with source as (
    select * from {{ source('bronze', 'users') }}
),

typed as (
    select
        cast(uuid as uuid) as user_id,
        trim(username) as username,
        lower(trim(username)) as username_normalized,
        trim(name) as name,
        upper(trim(sex)) as sex,
        lower(trim(mail)) as email,
        cast(birthdate as date) as birthdate,
        -- The address spans 2 lines: the street, then the city, the state and the zip code
        split_part(address, chr(10), 1) as street,
        split_part(address, chr(10), 2) as address_line_2
    from source
),

-- Exercise 3: a user cannot have ordered before being born. The first order date of
-- each user is read directly from the bronze orders source (not stg_orders), to avoid
-- making a staging model depend on another staging model.
first_order as (
    select
        cast(user_uuid as uuid) as user_id,
        min(cast(date as timestamptz)) as first_ordered_at
    from {{ source('bronze', 'orders') }}
    group by user_id
),

validated as (
    select
        typed.*,
        first_order.first_ordered_at,
        -- NULL first_ordered_at (user with no order) counts as valid: nothing to contradict
        (first_order.first_ordered_at is null or typed.birthdate <= first_order.first_ordered_at)
            as birthdate_is_valid
    from typed
    left join first_order on typed.user_id = first_order.user_id
)

select
    user_id,
    username,
    username_normalized,
    name,
    sex,
    email,
    case when birthdate_is_valid then birthdate else null end as birthdate,
    birthdate_is_valid,
    street,
    -- Military addresses, such as "DPO AE 12345", have no comma
    nullif(regexp_extract(address_line_2, '^(.+), [A-Z]{2} \d{5}$', 1), '') as city,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 1) as state,
    regexp_extract(address_line_2, '([A-Z]{2}) (\d{5})$', 2) as zip_code
from validated
