-- REAL data. Framework 2025 performance criteria, tested every year.
-- IM-02 PHN criterion: the PHN's reduction matches or exceeds the national reduction.
--   Tested year on year (the comparison period is an assumption, see framework_indicator_spec).
--   The change since 2017-18 is shown alongside so a committee sees both readings.
-- IM-01 has no PHN criterion (Part B: assessed at national level). The national criterion,
--   at least a 1% reduction in the national rate of total PPH, is tested year on year.
-- Pack status: Met = year on year criterion met; Watch = not met year on year but the PHN's
--   reduction since baseline still exceeds the national one; Not met = neither.
with im02 as (
    select fy_end_year, financial_year, geography_code, change_pct_year_on_year, change_pct_since_baseline, rate
    from {{ ref('im02_lower_urgency') }}
    where hour_band = 'All-hours' and geography_code in ('PHN206', '001NAT')
),

im02_check as (
    select
        'IM-02'                                     as indicator_code,
        'PHN'                                       as criterion_level,
        p.financial_year,
        p.fy_end_year,
        p.rate                                      as wvphn_value,
        n.rate                                      as national_value,
        p.change_pct_year_on_year                   as wvphn_change_pct_year_on_year,
        n.change_pct_year_on_year                   as national_change_pct_year_on_year,
        p.change_pct_since_baseline                 as wvphn_change_pct_since_baseline,
        n.change_pct_since_baseline                 as national_change_pct_since_baseline,
        p.change_pct_year_on_year <= n.change_pct_year_on_year         as is_met_year_on_year,
        p.change_pct_since_baseline <= n.change_pct_since_baseline     as is_met_since_baseline
    from im02 p
    join im02 n on n.fy_end_year = p.fy_end_year and n.geography_code = '001NAT'
    where p.geography_code = 'PHN206' and p.change_pct_year_on_year is not null
),

im02_national as (
    select
        'IM-02', 'National', financial_year, fy_end_year, null, rate,
        null, change_pct_year_on_year, null, change_pct_since_baseline,
        change_pct_year_on_year <= -1.0, null
    from im02
    where geography_code = '001NAT' and change_pct_year_on_year is not null
),

im01_national as (
    select
        'IM-01', 'National', financial_year, fy_end_year, null, rate,
        null, change_pct_year_on_year, null, change_pct_since_baseline,
        change_pct_year_on_year <= -1.0, null
    from {{ ref('im01_pph') }}
    where geography_code = '001NAT' and pph_category = 'PPH' and change_pct_year_on_year is not null
),

combined as (
    select * from im02_check
    union all
    select * from im02_national
    union all
    select * from im01_national
)

select
    *,
    case
        when is_met_year_on_year then 'Met'
        when is_met_since_baseline then 'Watch'
        else 'Not met'
    end as pack_status,
    fy_end_year = max(fy_end_year) over (partition by indicator_code, criterion_level) as is_latest_year
from combined
