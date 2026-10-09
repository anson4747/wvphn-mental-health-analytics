-- An episode cannot be contacted before it is referred, or end before it starts.
select episode_id, referral_date, first_contact_date, episode_end_date
from {{ ref('stg_pmhc__episodes') }}
where first_contact_date < referral_date
   or episode_end_date < referral_date
   or episode_end_date < first_contact_date
