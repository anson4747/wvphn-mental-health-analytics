select
    subregion,
    region,
    hub_town,
    population_2023::integer as population_2023
from {{ source('pmhc_synthetic', 'dim_subregion') }}
