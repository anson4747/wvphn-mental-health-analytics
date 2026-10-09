-- The AIHW extract must contain every Western Victoria SA3 in every financial year.
select fy_end_year, count(distinct sa3_code) as sa3s
from {{ ref('lower_urgency_ed_sa3') }}
group by fy_end_year
having count(distinct sa3_code) <> (select count(*) from {{ ref('stg_pmhc__sa3_subregion_map') }})
