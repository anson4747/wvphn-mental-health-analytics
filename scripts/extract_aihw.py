"""Cut the AIHW lower urgency ED release down to the rows this project uses.

The full CSV (aihw-phc-23, about 130 MB and 355,000 rows) is too large for the repository.
This script keeps national rows, every PHN (for benchmarking) and the ten SA3s that make up
Western Victoria PHN, for all persons, and writes a UTF-8 extract of about 0.5 MB.

Source: AIHW, Use of emergency departments for lower urgency care: 2017-18 to 2024-25
        https://www.aihw.gov.au/reports/primary-health-care/use-of-emergency-departments-lower-urgency-care
        Download "aihw-phc-23-csv-file-2017-18-to-2024-25.csv" from the report's data section.

Usage:
    python scripts/extract_aihw.py --src path/to/aihw-phc-23-csv-file-2017-18-to-2024-25.csv
"""

import argparse
from pathlib import Path

import pandas as pd

WVPHN_SA3S = [
    "Ballarat", "Creswick - Daylesford - Ballan", "Maryborough - Pyrenees",
    "Barwon - West", "Geelong", "Surf Coast - Bellarine Peninsula",
    "Warrnambool", "Colac - Corangamite", "Glenelg - Southern Grampians", "Grampians",
]

MEASURES = [
    "All-hours lower urgency ED, per 1,000 population, age-standardised",
    "In-hours lower urgency ED, per 1,000 population, age-standardised",
    "After-hours lower urgency ED, per 1,000 population, age-standardised",
    "Number all-hours lower urgency ED",
    "Number total ED",
    "Estimated resident population",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", required=True, help="full AIHW CSV")
    parser.add_argument("--out", default="data/raw/aihw/aihw_lower_urgency_ed_extract.csv")
    args = parser.parse_args()

    # The AIHW file is Windows-1252 encoded and uses en dashes in year and age labels
    df = pd.read_csv(args.src, encoding="cp1252", dtype=str)

    in_scope_geography = df.GeographicUnit.isin(["NAT", "PHN"]) | (
        (df.GeographicUnit == "SA3") & (df.StateTerritory == "Vic") & df.GeographicAreaName.isin(WVPHN_SA3S)
    )
    in_scope_measure = (
        df.MeasureName.isin(MEASURES)
        & (df.DemographicGroup == "All persons")
        & df.TriageCategory.isin(["TC4+5", "All"])
    )
    extract = df[in_scope_geography & in_scope_measure].drop(columns=["Code", "DataSource", "Name"])
    extract = extract.apply(lambda col: col.str.replace("–", "-", regex=False))

    missing = set(WVPHN_SA3S) - set(extract.loc[extract.GeographicUnit == "SA3", "GeographicAreaName"])
    if missing:
        raise SystemExit(f"SA3s missing from source: {sorted(missing)}")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    extract.to_csv(args.out, index=False, encoding="utf-8")
    print(f"{len(df):,} source rows -> {len(extract):,} rows written to {args.out}")


if __name__ == "__main__":
    main()
