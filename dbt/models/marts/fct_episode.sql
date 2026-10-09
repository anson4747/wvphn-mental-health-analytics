-- Episode grain fact with every flag the KPI layer needs, so KPIs are simple aggregations.
with episodes as (
    select * from {{ ref('stg_pmhc__episodes') }}
),

outcomes as (
    select * from {{ ref('int_episode_outcomes') }}
),

contacts as (
    select * from {{ ref('int_episode_contacts') }}
)

select
    e.episode_id,
    e.client_key,
    e.provider_code,
    e.referral_date,
    date_trunc('quarter', e.referral_date)::date                         as referral_quarter,
    e.first_contact_date,
    e.episode_end_date,
    date_trunc('quarter', e.episode_end_date)::date                      as end_quarter,
    e.completion_status,
    e.is_suicide_risk_referral,
    e.age_group,
    e.sex,
    e.indigenous_status,
    e.iar_level,

    -- access
    datediff('day', e.referral_date, e.first_contact_date)               as days_to_first_contact,
    e.is_suicide_risk_referral and e.first_contact_date is not null
        and datediff('day', e.referral_date, e.first_contact_date) <= 7  as is_followed_up_within_7_days,

    -- episode lifecycle
    e.completion_status in ('Treatment concluded', 'Client disengaged', 'Referred on') as is_completed,
    e.completion_status = 'Open'
        and e.first_contact_date
            < cast('{{ var("extract_date") }}' as date) - {{ var('stale_open_days') }} as is_stale_open,

    -- outcomes (lower is better, so negative change is improvement)
    o.outcome_measure,
    o.start_score,
    o.end_score,
    o.end_score - o.start_score                                          as score_change,
    coalesce(o.has_start_measure, false)                                 as has_start_measure,
    coalesce(o.has_end_measure, false)                                   as has_end_measure,
    coalesce(o.has_start_measure and o.has_end_measure, false)           as has_paired_measures,

    -- activity
    coalesce(c.contacts_booked, 0)                                       as contacts_booked,
    coalesce(c.contacts_attended, 0)                                     as contacts_attended,
    coalesce(c.minutes_attended, 0)                                      as minutes_attended,
    c.last_contact_date,
    e.data_source
from episodes e
left join outcomes o using (episode_id)
left join contacts c using (episode_id)
