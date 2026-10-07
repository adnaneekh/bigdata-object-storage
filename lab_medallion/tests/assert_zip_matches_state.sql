-- Exercise 4: detect a ZIP code whose first digit does not belong to the region of its
-- state. Reference data: zip_prefix_regions, the standard USPS first-digit-to-state(s)
-- regions. This is coarse (one digit, not the full 3-digit prefix) on purpose: the full
-- ZIP3-to-state table has hundreds of entries and would need to come from an authoritative
-- external source (e.g. USPS / Census Bureau), kept up to date as prefixes are reassigned.
-- The first-digit table is small, stable, and good enough to catch gross inconsistencies
-- like the generator's random "KY 01352" (Kentucky state code with a Connecticut/New-England
-- ZIP prefix).
select
    u.user_id,
    u.state,
    u.zip_code
from {{ ref('stg_users') }} u
left join {{ ref('zip_prefix_regions') }} z
    on left(u.zip_code, 1) = z.zip_prefix
    and u.state = z.state
where u.zip_code is not null
    and u.state is not null
    and z.state is null
