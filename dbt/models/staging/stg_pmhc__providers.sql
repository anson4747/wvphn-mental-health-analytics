select
    provider_code,
    provider_label,
    program_type,
    subregion,
    annual_episode_target::integer as annual_episode_target,
    data_source
from {{ source('pmhc_synthetic', 'dim_provider') }}
