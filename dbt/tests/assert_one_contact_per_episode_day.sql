-- At most one service contact per episode per day. Caught a sampling-with-replacement
-- defect in an earlier version of the generator (2,648 duplicate episode-days).
select episode_id, contact_date, count(*) as contacts
from {{ ref('stg_pmhc__service_contacts') }}
group by all
having count(*) > 1
