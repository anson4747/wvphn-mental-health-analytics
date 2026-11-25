-- REAL data. IM-02 by Western Victoria SA3 in the latest year, with the baseline year, the change,
-- position against the PHN and national rates, and how many Medicare Urgent Care Clinics and
-- commissioned after hours services sit in the SA3.
-- The service counts are a HYPOTHESIS LAYER: co-location is not evidence of cause.
with sa3 as (
    select * from {{ ref('lower_urgency_ed_sa3') }}
),

latest as (select max(fy_end_year) as fy from sa3),

phn as (
    select fy_end_year, geography_code, rate
    from {{ ref('im02_lower_urgency') }}
    where hour_band = 'All-hours' and geography_code in ('PHN206', '001NAT')
),

services as (
    select
        sa3_name,
        count(*) filter (where service_type = 'Medicare Urgent Care Clinic')       as urgent_care_clinics,
        count(*) filter (where service_type = 'Commissioned after hours service')  as after_hours_services
    from {{ ref('service_locations') }}
    group by sa3_name
)

select
    s.financial_year,
    s.sa3_code,
    s.sa3_name,
    s.subregion,
    s.rate_age_standardised                                                 as rate,
    b.rate_age_standardised                                                 as baseline_rate,
    round(100.0 * (s.rate_age_standardised / b.rate_age_standardised - 1), 1) as change_pct_since_baseline,
    s.after_hours_rate_age_standardised                                     as after_hours_rate,
    w.rate                                                                  as wvphn_rate,
    n.rate                                                                  as national_rate,
    round(s.rate_age_standardised / w.rate, 2)                              as ratio_to_wvphn,
    rank() over (order by s.rate_age_standardised desc)                    as rank_highest_first,
    coalesce(v.urgent_care_clinics, 0)                                      as urgent_care_clinics,
    coalesce(v.after_hours_services, 0)                                     as after_hours_services,
    s.rate_age_standardised > n.rate
        and s.rate_age_standardised > b.rate_age_standardised               as is_hotspot,
    s.is_flagged                                                            as aihw_comparability_flag
from sa3 s
cross join latest l
join sa3 b on b.sa3_code = s.sa3_code and b.fy_end_year = {{ var('impact_baseline_fy') }}
join phn w on w.fy_end_year = s.fy_end_year and w.geography_code = 'PHN206'
join phn n on n.fy_end_year = s.fy_end_year and n.geography_code = '001NAT'
left join services v on v.sa3_name = s.sa3_name
where s.fy_end_year = l.fy
