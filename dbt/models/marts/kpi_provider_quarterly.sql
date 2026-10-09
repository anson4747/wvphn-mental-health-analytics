-- Provider x quarter KPIs. Each KPI uses the date that defines its cohort:
--   access KPIs by referral quarter, outcome collection by episode end quarter.
with episodes as (
    select * from {{ ref('fct_episode') }}
),

quarters as (
    select distinct referral_quarter as quarter from episodes
),

spine as (
    select p.provider_code, q.quarter
    from {{ ref('dim_provider') }} p
    cross join quarters q
),

access as (
    select
        provider_code,
        referral_quarter                                                     as quarter,
        count(*)                                                             as referrals,
        median(days_to_first_contact)                                        as median_days_to_first_contact,
        count(*) filter (where is_suicide_risk_referral and first_contact_date is not null) as suicide_risk_referrals_contacted,
        count(*) filter (where is_followed_up_within_7_days)                 as suicide_risk_followed_up_7_days
    from episodes
    group by all
),

outcomes as (
    select
        provider_code,
        end_quarter                                                          as quarter,
        count(*)                                                             as episodes_completed,
        count(*) filter (where has_paired_measures)                          as episodes_completed_with_paired_measures
    from episodes
    where is_completed
    group by all
)

select
    s.provider_code,
    s.quarter,
    strftime(s.quarter, '%Y') || '-Q' || quarter(s.quarter)                  as quarter_label,
    coalesce(a.referrals, 0)                                                 as referrals,
    a.median_days_to_first_contact,
    coalesce(a.suicide_risk_referrals_contacted, 0)                          as suicide_risk_referrals_contacted,
    coalesce(a.suicide_risk_followed_up_7_days, 0)                           as suicide_risk_followed_up_7_days,
    a.suicide_risk_followed_up_7_days / nullif(a.suicide_risk_referrals_contacted, 0) as followup_7day_rate,
    coalesce(o.episodes_completed, 0)                                        as episodes_completed,
    coalesce(o.episodes_completed_with_paired_measures, 0)                   as episodes_completed_with_paired_measures,
    o.episodes_completed_with_paired_measures / nullif(o.episodes_completed, 0) as outcome_collection_rate
from spine s
left join access a using (provider_code, quarter)
left join outcomes o using (provider_code, quarter)
