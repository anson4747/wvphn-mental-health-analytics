-- Combines SYNTHETIC service activity with REAL population and REAL ED data at subregion level.
-- Episodes per 1,000 is illustrative only because the episode counts are synthetic.
with episodes as (
    select p.subregion, count(*) as referrals_18_months
    from {{ ref('fct_episode') }} e
    join {{ ref('dim_provider') }} p using (provider_code)
    group by all
),

ed as (
    select
        m.subregion,
        sum(a.measure_value) filter (where a.measure_name = 'Number all-hours lower urgency ED') as lower_urgency_ed_presentations,
        sum(a.measure_value) filter (where a.measure_name = 'Estimated resident population')     as ed_population
    from {{ ref('stg_aihw__lower_urgency_ed') }} a
    join {{ ref('stg_pmhc__sa3_subregion_map') }} m on a.geography_name = m.sa3_name
    where a.geography_level = 'SA3'
      and a.fy_end_year = (select max(fy_end_year) from {{ ref('stg_aihw__lower_urgency_ed') }})
      and a.triage_category = 'TC4+5'
    group by all
)

select
    s.subregion,
    s.region,
    s.population_2023,
    e.referrals_18_months,
    round(e.referrals_18_months / 1.5 / s.population_2023 * 1000, 1)          as referrals_per_1000_per_year,
    ed.lower_urgency_ed_presentations,
    round(ed.lower_urgency_ed_presentations / ed.ed_population * 1000, 1)     as lower_urgency_ed_per_1000_crude
from {{ ref('dim_subregion') }} s
left join episodes e using (subregion)
left join ed using (subregion)
