-- An episode with a first contact date must have at least one service contact record on that date.
select e.episode_id
from {{ ref('stg_pmhc__episodes') }} e
left join {{ ref('stg_pmhc__service_contacts') }} c
    on c.episode_id = e.episode_id and c.contact_date = e.first_contact_date
where e.first_contact_date is not null and c.contact_id is null
