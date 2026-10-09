select
    episode_id,
    client_key,
    provider_code,
    referral_date::date        as referral_date,
    first_contact_date::date   as first_contact_date,
    episode_end_date::date     as episode_end_date,
    completion_status,
    suicide_risk_referral = 'Yes' as is_suicide_risk_referral,
    age_group,
    sex,
    indigenous_status,
    iar_level::integer         as iar_level,
    data_source
from {{ source('pmhc_synthetic', 'fact_episode') }}
