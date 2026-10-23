-- Clean the AIHW potentially preventable hospitalisations extract (HPF-76):
--   * national rows are repeated identically across worksheets Table1 to Table4: keep one copy
--   * '003MET' and '003REG' are PHN groups (metropolitan / regional), not PHNs
--   * Murray PHN (PHN205) is listed under 'Vic/NSW'
--   * DemographicGroup is All persons, or 0-64 and 65+ for the PPH totals
--   * financial year '2017-18' becomes fy_end_year 2018 for sorting and joins
--   * values flagged n.p. (not published) or '-' (nil or rounded to zero) arrive as null
with source as (
    select * from {{ source('aihw', 'aihw_pph_extract') }}
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
        "GeographicGroup"                              as geographic_group,
        nullif("StateTerritory", '')                   as state,
        "DemographicGroup"                             as demographic_group,
        "PPHGroup"                                     as pph_group,
        "PPHCondition"                                 as pph_condition,
        "PPHCondition" like 'Total%'                   as is_group_total,
        case "MeasureName"
            when 'Hospitalisations per 100,000 people (age-standardised)' then 'rate_age_standardised'
            when 'Hospitalisations per 100,000 people (crude)'            then 'rate_crude'
            when 'Number of hospitalisations'                             then 'count'
            when 'Estimated resident population'                          then 'population'
        end                                            as measure_type,
        "MeasureName"                                  as measure_name,
        try_cast("MeasureValue" as double)             as measure_value,
        "Flag"                                         as flag,
        "FlagExplanation"                              as flag_explanation
    from source
)

select *
from typed
qualify row_number() over (
    partition by fy_end_year, geography_code, demographic_group, pph_group, pph_condition, measure_type
    order by state nulls last
) = 1
