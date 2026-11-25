-- REAL data (AIHW PHC-23). IM-02 lower urgency ED presentations, age-standardised per 1,000.
-- One row per financial year, geography and hour band, for Western Victoria, its comparators
-- (national, the regional PHN group, the two other Victorian regional PHNs) and every PHN.
with rates as (
    select
        fy_end_year,
        financial_year,
        geography_level,
        geography_code,
        geography_name,
        geographic_group,
        split_part(measure_name, ' lower urgency', 1) as hour_band,
        measure_value                               as rate
    from {{ ref('stg_aihw__lower_urgency_ed') }}
    where measure_type = 'rate_age_standardised'
      and triage_category = 'TC4+5'
      and geography_level in ('National', 'PHN', 'PHN group')
)

select
    'IM-02'                                                     as indicator_code,
    financial_year,
    fy_end_year,
    geography_level,
    geography_code,
    geography_name,
    case
        when geography_level = 'PHN' then geographic_group
        when geography_level = 'PHN group' then geography_name
        else 'National'
    end                                                         as peer_group,
    geography_code = 'PHN206'                                   as is_wvphn,
    geography_code in ('PHN204', 'PHN205', 'PHN206')            as is_victorian_regional,
    hour_band,
    rate,
    lag(rate) over w                                            as prior_year_rate,
    round(100.0 * (rate / lag(rate) over w - 1), 1)             as change_pct_year_on_year,
    first_value(rate) over w                                    as baseline_rate,
    round(100.0 * (rate / first_value(rate) over w - 1), 1)     as change_pct_since_baseline
from rates
window w as (partition by geography_code, hour_band order by fy_end_year)
