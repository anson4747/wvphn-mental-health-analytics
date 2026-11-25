-- REAL data. IM-01 total PPH by age group (0-64 and 65+), a framework disaggregation, for
-- Western Victoria, the regional PHN group and Australia, by year. AIHW does not publish
-- age-standardised rates within an age band (flagged 'Not applicable'), so these are CRUDE rates
-- per 100,000 and are compared within the same band only.
select
    p.financial_year,
    p.fy_end_year,
    p.geography_code,
    p.geography_name,
    p.demographic_group                                                         as age_group,
    p.measure_value                                                             as crude_rate,
    round(100.0 * (p.measure_value / first_value(p.measure_value) over w - 1), 1) as change_pct_since_baseline,
    round(100.0 * (p.measure_value / lag(p.measure_value) over w - 1), 1)         as change_pct_year_on_year
from {{ ref('stg_aihw__pph') }} p
where p.measure_type = 'rate_crude'
  and p.pph_condition = 'Total PPH'
  and p.demographic_group in ('0-64', '65+')
  and p.geography_code in ('PHN206', '003REG', '001NAT')
window w as (partition by p.geography_code, p.demographic_group order by p.fy_end_year)
