-- Every service location must sit in one of the ten Western Victoria SA3s.
select s.*
from {{ ref('service_locations') }} s
left join {{ ref('stg_pmhc__sa3_subregion_map') }} m on m.sa3_name = s.sa3_name
where m.sa3_name is null
