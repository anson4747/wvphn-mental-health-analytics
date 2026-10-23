-- IM-02 must have all three hour bands for Western Victoria and Australia in every year
-- from 2017-18 to 2024-25 (8 years x 3 bands x 2 geographies = 48 rows).
select count(*) as row_count
from {{ ref('im02_lower_urgency') }}
where geography_code in ('PHN206', '001NAT') and rate is not null
having count(*) <> 48
