select provider_code, quarter, followup_7day_rate, outcome_collection_rate
from {{ ref('kpi_provider_quarterly') }}
where followup_7day_rate not between 0 and 1
   or outcome_collection_rate not between 0 and 1
