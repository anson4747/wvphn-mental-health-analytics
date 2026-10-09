-- Provider scorecard for the latest complete half year (January to June 2026), with status
-- against the targets set in dbt_project.yml. Status is 'On target' or 'Below target'.
with episodes as (
    select * from {{ ref('fct_episode') }}
),

period as (
    select date '2026-01-01' as period_start, cast('{{ var("extract_date") }}' as date) as period_end
),

referred as (
    select
        provider_code,
        count(*)                                                                  as referrals,
        median(days_to_first_contact)                                             as median_days_to_first_contact,
        count(*) filter (where is_suicide_risk_referral and first_contact_date is not null) as suicide_risk_referrals_contacted,
        count(*) filter (where is_followed_up_within_7_days)                      as suicide_risk_followed_up_7_days
    from episodes, period
    where referral_date between period_start and period_end
    group by all
),

completed as (
    select
        provider_code,
        count(*)                                                                  as episodes_completed,
        count(*) filter (where has_paired_measures)                               as episodes_with_paired_measures,
        avg(score_change) filter (where has_paired_measures)                      as avg_score_change
    from episodes, period
    where is_completed and episode_end_date between period_start and period_end
    group by all
),

backlog as (
    select
        provider_code,
        count(*) filter (where completion_status = 'Open')                        as open_episodes,
        count(*) filter (where is_stale_open)                                     as stale_open_episodes
    from episodes
    group by all
),

scored as (
    select
        p.provider_code,
        p.provider_label,
        p.program_type,
        p.subregion,
        r.referrals,
        r.median_days_to_first_contact,
        r.suicide_risk_followed_up_7_days / nullif(r.suicide_risk_referrals_contacted, 0) as followup_7day_rate,
        r.suicide_risk_referrals_contacted,
        c.episodes_completed,
        c.episodes_with_paired_measures / nullif(c.episodes_completed, 0)                 as outcome_collection_rate,
        c.avg_score_change,
        b.open_episodes,
        b.stale_open_episodes,
        b.stale_open_episodes / nullif(b.open_episodes, 0)                                as stale_open_share
    from {{ ref('dim_provider') }} p
    left join referred r using (provider_code)
    left join completed c using (provider_code)
    left join backlog b using (provider_code)
)

select
    *,
    case when median_days_to_first_contact <= {{ var('target_median_wait_days') }}
         then 'On target' else 'Below target' end                                as wait_status,
    case when followup_7day_rate >= {{ var('target_7day_followup_rate') }}
         then 'On target' else 'Below target' end                                as followup_status,
    case when outcome_collection_rate >= {{ var('target_outcome_collection_rate') }}
         then 'On target' else 'Below target' end                                as outcome_collection_status
from scored
