-- Clean the AIHW long-format extract:
--   * national rows are repeated identically across worksheets Table1 to Table4: keep one copy
--   * '003MET' and '003REG' are PHN groups (metropolitan / regional), not PHNs
--   * Murray PHN (PHN205) appears under both 'Vic' and 'Vic/NSW': keep one row per measure
--   * financial year '2017-18' becomes fy_end_year 2018 for sorting and joins
with source as (
    select * from {{ source('aihw', 'aihw_lower_urgency_ed_extract') }}
),

typed as (
    select
        "Year"                                         as financial_year,
        cast(substr("Year", 1, 4) as integer) + 1     as fy_end_year,
        case
            when "GeographicUnit" = 'PHN' and "GeographicCode" in ('003MET', '003REG') then 'PHN group'
            when "GeographicUnit" = 'NAT' then 'National'
            else "GeographicUnit"
        end                                            as geography_level,
        "GeographicCode"                               as geography_code,
        "GeographicAreaName"                           as geography_name,
        nullif("StateTerritory", '')                   as state,
        "TriageCategory"                               as triage_category,
        coalesce(nullif("HourEDpresentation", ''), 'Not applicable') as hour_band,
        "MeasureName"                                  as measure_name,
        try_cast("MeasureValue" as double)             as measure_value,
        "Flag" is not null                             as is_flagged,
        "FlagExplanation"                              as flag_explanation
    from source
),

deduplicated as (
    select *
    from typed
    qualify row_number() over (
        partition by fy_end_year, geography_level, geography_code, triage_category, hour_band, measure_name
        order by state nulls last
    ) = 1
)

select
    *,
    case
        when measure_name like '%age-standardised' then 'rate_age_standardised'
        when measure_name like '%per 1,000 population' then 'rate_crude'
        when measure_name like 'Number%' then 'count'
        when measure_name = 'Estimated resident population' then 'population'
    end as measure_type
from deduplicated
