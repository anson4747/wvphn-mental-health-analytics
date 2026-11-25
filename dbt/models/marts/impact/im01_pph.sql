-- REAL data (AIHW HPF-76). IM-01 potentially preventable hospitalisations, age-standardised per
-- 100,000, by year, geography and PPH group (Total PPH, Acute, Chronic, Vaccine-preventable),
-- with year on year change and change since 2017-18. Lower is better.
with rates as (
    select
        fy_end_year,
        financial_year,
        geography_level,
        geography_code,
        geography_name,
        geographic_group,
        pph_condition                       as pph_category,
        measure_value                       as rate
    from {{ ref('stg_aihw__pph') }}
    where measure_type = 'rate_age_standardised'
      and demographic_group = 'All persons'
      and pph_condition in ('Total PPH', 'Total acute', 'Total chronic', 'Total vaccine-preventable')
      and geography_level in ('National', 'PHN', 'PHN group')
)

select
    'IM-01'                                                     as indicator_code,
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
    replace(pph_category, 'Total ', '')                         as pph_category,
    rate,
    lag(rate) over w                                            as prior_year_rate,
    round(100.0 * (rate / lag(rate) over w - 1), 1)             as change_pct_year_on_year,
    first_value(rate) over w                                    as baseline_rate,
    round(100.0 * (rate / first_value(rate) over w - 1), 1)     as change_pct_since_baseline
from rates
window w as (partition by geography_code, pph_category order by fy_end_year)
