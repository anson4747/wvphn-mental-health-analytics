-- K10+ total ranges 10 to 50; SDQ total difficulties ranges 0 to 40.
select measure_id, measure, score
from {{ ref('stg_pmhc__outcome_measures') }}
where (measure = 'K10+' and score not between 10 and 50)
   or (measure = 'SDQ'  and score not between 0 and 40)
