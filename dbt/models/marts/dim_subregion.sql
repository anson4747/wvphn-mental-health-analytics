select
    s.subregion,
    s.region,
    s.hub_town,
    s.population_2023,
    count(m.sa3_name)                         as sa3_count,
    string_agg(m.sa3_name, ', ' order by m.sa3_name) as sa3_names
from {{ ref('stg_pmhc__subregions') }} s
left join {{ ref('stg_pmhc__sa3_subregion_map') }} m using (subregion)
group by all
