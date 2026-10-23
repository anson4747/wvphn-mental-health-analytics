-- REAL data. Western Victoria against AIHW's regional PHN group in the latest year.
-- The framework compares PHNs within peer groups (remoteness, SEIFA, state) but does not
-- publish membership, so AIHW's Regional PHN classification is used as an APPROXIMATION.
-- Lower is better for both impact indicators, so rank 1 is the lowest rate.
with im02 as (
    select *
    from {{ ref('im02_lower_urgency') }}
    where hour_band = 'All-hours'
      and fy_end_year = (select max(fy_end_year) from {{ ref('im02_lower_urgency') }})
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
        rank() over (order by rate)        as rank_lowest_first,
        count(*) over ()                    as peer_count,
        median(rate) over ()                as peer_median
    from im02
    where geography_level = 'PHN' and peer_group = 'Regional'
)

select
    p.*,
    g.rate                          as regional_group_rate,
    n.rate                          as national_rate
from peers p
join im02 g on g.geography_code = '003REG'
join im02 n on n.geography_code = '001NAT'
