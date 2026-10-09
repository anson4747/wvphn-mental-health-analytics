select
    contact_id,
    episode_id,
    contact_date::date          as contact_date,
    modality,
    duration_minutes::integer   as duration_minutes,
    attended = 'Yes'            as is_attended
from {{ source('pmhc_synthetic', 'fact_service_contact') }}
