-- Every service contact falls between the episode's first contact and its end (or the extract date).
select c.contact_id, c.contact_date, e.first_contact_date, e.episode_end_date
from {{ ref('stg_pmhc__service_contacts') }} c
join {{ ref('stg_pmhc__episodes') }} e using (episode_id)
where c.contact_date < e.first_contact_date
   or c.contact_date > coalesce(e.episode_end_date, cast('{{ var("extract_date") }}' as date))
