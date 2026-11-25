-- IM-01 must have all four PPH categories for Western Victoria and Australia in every year
-- from 2017-18 to 2023-24 (7 years x 4 categories x 2 geographies = 56 rows).
select count(*) as row_count
from {{ ref('im01_pph') }}
where geography_code in ('PHN206', '001NAT') and rate is not null
having count(*) <> 56
