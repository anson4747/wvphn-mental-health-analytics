select
    measure_id,
    episode_id,
    measure,
    case collection_occasion
        when 'Episode start' then 'start'
        when 'Episode end'   then 'end'
    end                          as collection_occasion,
    collection_date::date        as collection_date,
    score::integer               as score
from {{ source('pmhc_synthetic', 'fact_outcome_measure') }}
