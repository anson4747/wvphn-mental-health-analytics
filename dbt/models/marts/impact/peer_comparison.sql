-- REAL data. Western Victoria against AIHW's regional PHN group in the latest year of each
-- indicator (IM-01 2023-24, IM-02 2024-25). The framework compares PHNs within peer groups
-- (remoteness, SEIFA, state) but does not publish membership, so AIHW's Regional PHN
-- classification is used as an APPROXIMATION. Lower is better for both, so rank 1 is lowest.
with indicators as (
    select indicator_code, financial_year, fy_end_year, geography_level, geography_code,
           geography_name, peer_group, is_wvphn, is_victorian_regional, rate, change_pct_since_baseline
    from {{ ref('im02_lower_urgency') }}
    where hour_band = 'All-hours'
    union all
    select indicator_code, financial_year, fy_end_year, geography_level, geography_code,
           geography_name, peer_group, is_wvphn, is_victorian_regional, rate, change_pct_since_baseline
    from {{ ref('im01_pph') }}
    where pph_category = 'PPH'
),

latest as (
    select *
    from indicators
    qualify fy_end_year = max(fy_end_year) over (partition by indicator_code)
),

peers as (
    select
        indicator_code,
        financial_year,
        geography_code,
        geography_name,
        is_wvphn,
        is_victorian_regional,
        rate,
        change_pct_since_baseline,
        rank() over (partition by indicator_code order by rate)  as rank_lowest_first,
        count(*) over (partition by indicator_code)              as peer_count,
        median(rate) over (partition by indicator_code)          as peer_median
    from latest
    where geography_level = 'PHN' and peer_group = 'Regional'
)

select
    p.*,
    g.rate                          as regional_group_rate,
    n.rate                          as national_rate
from peers p
join latest g on g.indicator_code = p.indicator_code and g.geography_code = '003REG'
join latest n on n.indicator_code = p.indicator_code and n.geography_code = '001NAT'
