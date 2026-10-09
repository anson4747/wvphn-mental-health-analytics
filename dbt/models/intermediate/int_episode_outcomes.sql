-- One row per episode with its start and end outcome scores side by side.
-- Lower scores are better on both K10+ and SDQ, so a negative change is an improvement.
with measures as (
    select * from {{ ref('stg_pmhc__outcome_measures') }}
)

select
    episode_id,
    any_value(measure)                                                  as outcome_measure,
    max(score) filter (where collection_occasion = 'start')             as start_score,
    max(score) filter (where collection_occasion = 'end')               as end_score,
    count(*) filter (where collection_occasion = 'start') > 0           as has_start_measure,
    count(*) filter (where collection_occasion = 'end') > 0             as has_end_measure
from measures
group by episode_id
