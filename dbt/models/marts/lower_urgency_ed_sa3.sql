-- REAL data. Lower urgency ED use for each Western Victoria SA3, mapped to WVPHN subregions.
select
    a.financial_year,
    a.fy_end_year,
    a.geography_code                 as sa3_code,
    a.geography_name                 as sa3_name,
    m.subregion,
    max(a.measure_value) filter (where a.measure_name = 'All-hours lower urgency ED, per 1,000 population, age-standardised') as rate_age_standardised,
    max(a.measure_value) filter (where a.measure_name = 'After-hours lower urgency ED, per 1,000 population, age-standardised') as after_hours_rate_age_standardised,
    max(a.measure_value) filter (where a.measure_name = 'Number all-hours lower urgency ED') as lower_urgency_presentations,
    max(a.measure_value) filter (where a.measure_name = 'Estimated resident population')    as population,
    bool_or(a.is_flagged)            as is_flagged
from {{ ref('stg_aihw__lower_urgency_ed') }} a
join {{ ref('stg_pmhc__sa3_subregion_map') }} m on a.geography_name = m.sa3_name
where a.geography_level = 'SA3' and a.triage_category = 'TC4+5'
group by all
