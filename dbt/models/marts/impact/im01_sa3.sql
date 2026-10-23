-- REAL data. IM-01 total PPH by Western Victoria SA3 and year, with change since 2017-18 and
-- the PHN and national rates for the same year.
with sa3 as (
    select p.fy_end_year, p.financial_year, p.geography_code as sa3_code, p.geography_name as sa3_name,
           m.subregion, p.measure_value as rate, p.flag
    from {{ ref('stg_aihw__pph') }} p
    join {{ ref('stg_pmhc__sa3_subregion_map') }} m on m.sa3_name = p.geography_name
    where p.geography_level = 'SA3'
      and p.measure_type = 'rate_age_standardised'
      and p.pph_condition = 'Total PPH'
),

ref_rates as (
    select fy_end_year, geography_code, rate
    from {{ ref('im01_pph') }}
    where pph_category = 'PPH' and geography_code in ('PHN206', '001NAT')
)

select
    s.*,
    first_value(s.rate) over (partition by s.sa3_code order by s.fy_end_year)                        as baseline_rate,
    round(100.0 * (s.rate / first_value(s.rate) over (partition by s.sa3_code order by s.fy_end_year) - 1), 1)
                                                                                                      as change_pct_since_baseline,
    w.rate                                                                                            as wvphn_rate,
    n.rate                                                                                            as national_rate,
    rank() over (partition by s.fy_end_year order by s.rate desc)                                    as rank_highest_first
from sa3 s
join ref_rates w on w.fy_end_year = s.fy_end_year and w.geography_code = 'PHN206'
join ref_rates n on n.fy_end_year = s.fy_end_year and n.geography_code = '001NAT'
