select
    sa3_name,
    subregion
from {{ source('pmhc_synthetic', 'map_sa3_subregion') }}
