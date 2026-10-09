-- REAL data. Western Victoria PHN against Australia and the other 30 PHNs, per financial year.
-- Measure: all-hours lower urgency (triage 4 and 5) ED presentations per 1,000, age-standardised.
with rates as (
    select fy_end_year, financial_year, geography_level, geography_code, geography_name, measure_value as rate
    from {{ ref('stg_aihw__lower_urgency_ed') }}
    where measure_name = 'All-hours lower urgency ED, per 1,000 population, age-standardised'
      and triage_category = 'TC4+5'
      and hour_band = 'All-hours'
),

phn as (
    select
        *,
        rank() over (partition by fy_end_year order by rate desc) as rank_highest_first,
        count(*) over (partition by fy_end_year)                   as phn_count,
        median(rate) over (partition by fy_end_year)               as phn_median_rate
    from rates
    where geography_level = 'PHN' and rate is not null
)

select
    p.financial_year,
    p.fy_end_year,
    p.rate                         as wvphn_rate,
    n.rate                         as national_rate,
    p.phn_median_rate,
    round(p.rate - n.rate, 1)      as gap_to_national,
    p.rank_highest_first           as wvphn_rank_highest_first,
    p.phn_count
from phn p
join rates n on n.fy_end_year = p.fy_end_year and n.geography_level = 'National'
where p.geography_code = 'PHN206'
