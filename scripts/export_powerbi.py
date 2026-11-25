"""Export the Impact Indicator Pack marts to CSV for the Power BI report.

Power BI Desktop reads these files from powerbi/data. Every file comes from a tested dbt mart,
so the report never recalculates a figure the pipeline has already reconciled to AIHW.

Usage:
    python scripts/export_powerbi.py --db dbt/wvphn.duckdb --out powerbi/data
"""

import argparse
from pathlib import Path

import duckdb

TABLES = {
    "im01_pph": "select * from marts.im01_pph order by geography_code, pph_category, fy_end_year",
    "im01_age": "select * from marts.im01_age order by geography_code, age_group, fy_end_year",
    "im01_conditions": "select * from marts.im01_conditions order by pph_group, pph_condition",
    "im01_sa3": "select * from marts.im01_sa3 order by sa3_name, fy_end_year",
    "im02_lower_urgency": "select * from marts.im02_lower_urgency order by geography_code, hour_band, fy_end_year",
    "im02_sa3": "select * from marts.lower_urgency_ed_sa3 order by sa3_name, fy_end_year",
    "im02_sa3_hotspots": "select * from marts.im02_sa3_hotspots order by rank_highest_first",
    "peer_comparison": "select * from marts.peer_comparison order by indicator_code, rank_lowest_first",
    "criteria_check": "select * from marts.criteria_check order by indicator_code, criterion_level, fy_end_year",
    "indicator_spec": "select * from reference.framework_indicator_spec order by indicator_code",
    "service_locations": "select * from reference.service_locations order by service_type, location",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--db", default="dbt/wvphn.duckdb")
    parser.add_argument("--out", default="powerbi/data")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(args.db, read_only=True)
    for name, sql in TABLES.items():
        df = con.sql(sql).df()
        df.to_csv(out / f"{name}.csv", index=False, encoding="utf-8")
        print(f"{name}: {len(df):,} rows")


if __name__ == "__main__":
    main()
