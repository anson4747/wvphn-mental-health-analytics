-- Every published AIHW value in seeds/published_reference_values.csv must be reproduced by the
-- marts within the reconciliation tolerance. Returns the rows that do not reconcile.
with modelled as (
    select indicator_code, geography_code, fy_end_year, hour_band, rate as modelled_value
    from {{ ref('im02_lower_urgency') }}
)

select r.*, m.modelled_value
from {{ ref('published_reference_values') }} r
left join modelled m
    on  m.indicator_code = r.indicator_code
    and m.geography_code = r.geography_code
    and m.fy_end_year = r.fy_end_year
    and m.hour_band = r.hour_band
where m.modelled_value is null
   or abs(m.modelled_value - r.published_value) > {{ var('reconciliation_tolerance') }}
