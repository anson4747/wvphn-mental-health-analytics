# Data quality log

## Tests in the build

`dbt build` runs 59 data tests. A failure stops the models downstream of it.

| Kind | Examples | Protects against |
|---|---|---|
| Keys | `unique` and `not_null` on every primary key; unique combinations on composite grains | Duplicate rows inflating counts |
| Referential integrity | episodes to providers, contacts and measures to episodes, providers and SA3s to subregions | Orphan records silently dropped by joins |
| Domains | completion status, program type, IAR level 1 to 5, measure type, collection occasion | New codes appearing without the logic being updated |
| `assert_episode_dates_in_order` | contact before referral, end before start | Negative wait times |
| `assert_contacts_within_episode` | contacts outside the episode window | Activity credited to the wrong episode |
| `assert_one_contact_per_episode_day` | more than one contact per episode per day | Double counted activity |
| `assert_contacted_episodes_have_contact` | a first contact date with no contact record | Fact and detail disagreeing |
| `assert_outcome_scores_within_scale` | K10+ outside 10 to 50, SDQ outside 0 to 40 | Impossible scores skewing outcome change |
| `assert_kpi_rates_between_0_and_1` | rates outside 0 to 1 | Broken denominators |
| `assert_all_wvphn_sa3s_present_each_year` | an SA3 missing from a year | Gaps in the regional trend |
| `phn_count` accepted value 31 | PHN groups leaking into the PHN ranking | Wrong benchmark rank |

## Issues found and fixed

| # | Where | Issue | Found by | Fix |
|---|---|---|---|---|
| 1 | Synthetic generator | Contact days sampled with replacement: 2,648 episode-days had two or more contacts | `assert_one_contact_per_episode_day` (FAIL 2648) | Sample distinct days per episode |
| 2 | Synthetic generator | SDQ scores clipped to a floor of 10; the SDQ total difficulties scale runs 0 to 40 | Review against the instrument definition | Measure specific score ranges |
| 3 | AIHW source | File is Windows-1252 encoded with en dashes in year labels (`2017–18`) | Profiling | Read as cp1252, normalise to ASCII hyphen in the extract |
| 4 | AIHW source | National rows repeated identically across worksheets Table1 to Table4 | Profiling: 4 rows per national measure per year | Deduplicate in staging |
| 5 | AIHW source | `003MET` and `003REG` (metropolitan and regional PHN groups) listed as PHNs | Profiling: 33 "PHNs" against 31 real | Classified as `PHN group`; ranking test expects 31 |
| 6 | AIHW source | Murray PHN appears under both `Vic` and `Vic/NSW` | Profiling | Keep one row per measure |
| 7 | AIHW source | 130 MB file exceeds GitHub's 100 MB limit | Repository constraint | `scripts/extract_aihw.py` keeps the 2,256 rows used (0.5 MB) |

## Known limitations

* AIHW flags 9 of the 10 Western Victoria SA3s: results only include formal public EDs, which affects
  comparability for regional areas.
* `subregion_service_reach` divides synthetic referrals by real population. It shows the method, not
  real service reach.
* About 5 synthetic client keys repeat across episodes by chance. The model does not assume one
  episode per client.
