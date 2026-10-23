-- REAL data. Latest year IM-01 by condition for Western Victoria against the regional PHN group
-- and Australia, to show which conditions drive the gap. Rates are age-standardised per 100,000.
with c as (
    select fy_end_year, financial_year, geography_code, pph_group, pph_condition, measure_value as rate, flag
    from {{ ref('stg_aihw__pph') }}
    where measure_type = 'rate_age_standardised'
      and demographic_group = 'All persons'
      and not is_group_total
      and geography_code in ('PHN206', '003REG', '001NAT')
      and fy_end_year = (select max(fy_end_year) from {{ ref('stg_aihw__pph') }})
)

select
    w.financial_year,
    w.pph_group,
    w.pph_condition,
    w.rate                                  as wvphn_rate,
    r.rate                                  as regional_group_rate,
    n.rate                                  as national_rate,
    round(w.rate - r.rate, 0)               as gap_to_regional,
    round(w.rate - n.rate, 0)               as gap_to_national,
    w.flag                                  as wvphn_flag
from c w
left join c r on r.pph_group = w.pph_group and r.pph_condition = w.pph_condition and r.geography_code = '003REG'
left join c n on n.pph_group = w.pph_group and n.pph_condition = w.pph_condition and n.geography_code = '001NAT'
where w.geography_code = 'PHN206'
