"""Cut the AIHW potentially preventable hospitalisations release down to the rows this project uses.

The full CSV (aihw-hpf-76, about 250 MB and 868,000 rows) is too large for the repository.
This script keeps national rows, every PHN (and the metropolitan and regional PHN groups) for
benchmarking, and the ten SA3s that make up Western Victoria PHN, for all persons (plus the
0-64 and 65+ split for PPH totals) and for the measures used by indicator IM-01. It writes a UTF-8 extract of about 7 MB.

Source: AIHW, Potentially preventable hospitalisations in Australia by small geographic areas,
        2017-18 to 2023-24 (HPF-76). Download the CSV zip from the report's data section and
        extract "aihw-hpf-76-csv-file-2017-18-to-2023-24.csv".

Usage:
    python scripts/extract_aihw_pph.py --src path/to/aihw-hpf-76-csv-file-2017-18-to-2023-24.csv
    python scripts/extract_aihw_pph.py --src ... --profile   # print distinct values and exit
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
    "Hospitalisations per 100,000 people (age-standardised)",
    "Hospitalisations per 100,000 people (crude)",
    "Number of hospitalisations",
    "Estimated resident population",
]

PROFILE_COLUMNS = [
    "Worksheet", "Year", "StateTerritory", "GeographicUnit", "GeographicGroup",
    "DemographicGroup", "PPHGroup", "PPHCondition", "MeasureName", "Flag",
]


def read_source(path):
    # AIHW CSVs are Windows-1252 encoded and use en dashes in year and age labels
    return pd.read_csv(path, encoding="cp1252", dtype=str)


def profile(df):
    print(f"rows {len(df):,}")
    for col in PROFILE_COLUMNS:
        counts = df[col].value_counts(dropna=False)
        print(f"\n== {col}: {len(counts)} distinct")
        for value, n in counts.head(60).items():
            print(f"  {n:>8}  {value}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", required=True, help="full AIHW HPF-76 CSV")
    parser.add_argument("--out", default="data/raw/aihw/aihw_pph_extract.csv")
    parser.add_argument("--profile", action="store_true", help="print distinct values and exit")
    args = parser.parse_args()

    df = read_source(args.src)
    if args.profile:
        profile(df)
        return

    in_scope_geography = df.GeographicUnit.isin(["NAT", "PHN"]) | (
        (df.GeographicUnit == "SA3")
        & df.StateTerritory.fillna("").str.contains("Vic")
        & df.GeographicAreaName.isin(WVPHN_SA3S)
    )
    # All persons for every condition; the 0-64 and 65+ split (a framework disaggregation)
    # for the PPH totals only, to keep the extract small
    all_persons = df.DemographicGroup == "All persons"
    age_split = df.DemographicGroup.isin(["0\u201364", "65+"]) & df.PPHCondition.str.startswith("Total")
    in_scope_measure = df.MeasureName.isin(MEASURES) & (all_persons | age_split)
    extract = df[in_scope_geography & in_scope_measure].drop(columns=["Code", "DataSource", "Name"])
    extract = extract.apply(lambda col: col.str.replace("–", "-", regex=False))

    absent = set(MEASURES) - set(extract.MeasureName)
    if absent:
        raise SystemExit(f"Measures missing from source: {sorted(absent)}")
    missing = set(WVPHN_SA3S) - set(extract.loc[extract.GeographicUnit == "SA3", "GeographicAreaName"])
    if missing:
        raise SystemExit(f"SA3s missing from source: {sorted(missing)}")
    if not (extract.GeographicCode == "PHN206").any():
        raise SystemExit("Western Victoria PHN (PHN206) missing from extract")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    extract.to_csv(args.out, index=False, encoding="utf-8")
    print(f"{len(df):,} source rows -> {len(extract):,} rows written to {args.out}")


if __name__ == "__main__":
    main()
