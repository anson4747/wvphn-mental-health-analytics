-- Contact activity rolled up to the episode.
select
    episode_id,
    count(*)                                         as contacts_booked,
    count(*) filter (where is_attended)              as contacts_attended,
    sum(duration_minutes) filter (where is_attended) as minutes_attended,
    max(contact_date)                                as last_contact_date
from {{ ref('stg_pmhc__service_contacts') }}
group by episode_id
