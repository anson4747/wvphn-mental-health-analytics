select
    p.provider_code,
    p.provider_label,
    p.program_type,
    p.subregion,
    s.region,
    p.annual_episode_target,
    p.data_source
from {{ ref('stg_pmhc__providers') }} p
left join {{ ref('stg_pmhc__subregions') }} s using (subregion)
