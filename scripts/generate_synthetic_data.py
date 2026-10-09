"""Generate synthetic commissioned mental health service data for Western Victoria PHN.

The output follows the shape of the national Primary Mental Health Care Minimum Data Set
(PMHC MDS): episodes of care, service contacts and outcome measures, plus provider and
subregion dimensions. Providers, clients and services are fictional. Subregion
populations and the SA3 to subregion mapping are real (WVPHN Health Needs Assessment).

Each synthetic provider has a behaviour profile so the KPI layer has known issues to find:

    GS-02  long waits to first contact (median about 24 days)
    BG-02  7 day follow up of suicide risk referrals drops to about 68% from January 2026
    WG-01  low episode end outcome collection and poor episode closure
    GS-01  same problem as WG-01, fixed from March 2026

The random seed is fixed, so every run produces identical files.

Usage:
    python scripts/generate_synthetic_data.py --out data/raw/synthetic
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 20261006
EXTRACT_DATE = pd.Timestamp("2026-06-30")
PERIOD_START, PERIOD_END = pd.Timestamp("2025-01-01"), pd.Timestamp("2026-06-30")

# Real: WVPHN Health Needs Assessment 2026 update (2023 estimated resident population)
SUBREGIONS = pd.DataFrame(
    {
        "subregion": ["Geelong Otway", "Ballarat Goldfields", "Great South Coast", "Wimmera Grampians"],
        "region": ["Barwon South West", "Grampians", "Barwon South West", "Grampians"],
        "population_2023": [373430, 170228, 105957, 59758],
        "hub_town": ["Geelong", "Ballarat", "Warrnambool", "Horsham"],
    }
)

# Real: SA3 to subregion mapping (HNA Table 2), used to join the AIHW data
SA3_MAP = pd.DataFrame(
    [
        ("Ballarat", "Ballarat Goldfields"),
        ("Creswick - Daylesford - Ballan", "Ballarat Goldfields"),
        ("Maryborough - Pyrenees", "Ballarat Goldfields"),
        ("Barwon - West", "Geelong Otway"),
        ("Geelong", "Geelong Otway"),
        ("Surf Coast - Bellarine Peninsula", "Geelong Otway"),
        ("Warrnambool", "Great South Coast"),
        ("Colac - Corangamite", "Great South Coast"),
        ("Glenelg - Southern Grampians", "Great South Coast"),
        ("Grampians", "Wimmera Grampians"),
    ],
    columns=["sa3_name", "subregion"],
)

# Synthetic: de-identified provider codes so no real organisation is implied
PROVIDERS = pd.DataFrame(
    [
        ("GO-01", "Geelong Otway", "Psychological therapies", 1700),
        ("GO-02", "Geelong Otway", "Youth enhanced services", 800),
        ("GO-03", "Geelong Otway", "Low intensity", 1300),
        ("BG-01", "Ballarat Goldfields", "Clinical care coordination", 500),
        ("BG-02", "Ballarat Goldfields", "Psychological therapies", 1100),
        ("WG-01", "Wimmera Grampians", "Low intensity", 600),
        ("GS-01", "Great South Coast", "Psychological therapies", 650),
        ("GS-02", "Great South Coast", "Clinical care coordination", 350),
    ],
    columns=["provider_code", "subregion", "program_type", "annual_episode_target"],
)

EPISODE_DAYS = {"Low intensity": 45, "Psychological therapies": 110, "Youth enhanced services": 130, "Clinical care coordination": 180}
CONTACTS_PER_EPISODE = {"Low intensity": 4, "Psychological therapies": 7, "Youth enhanced services": 9, "Clinical care coordination": 10}
SCORE_RANGE = {"K10+": (10, 50), "SDQ": (0, 40)}  # K10+ total 10 to 50; SDQ total difficulties 0 to 40


def behaviour_profiles():
    profiles = {code: dict(wait_med=9, fu7=0.93, end_measure=0.86, close_ok=0.95) for code in PROVIDERS.provider_code}
    profiles["GS-02"]["wait_med"] = 24
    profiles["BG-02"]["fu7_2026"] = 0.68
    profiles["WG-01"].update(end_measure=0.45, close_ok=0.55)
    profiles["GS-01"].update(end_measure=0.40, close_ok=0.50, fix_from=pd.Timestamp("2026-03-01"))
    return profiles


def generate_episodes(rng, providers, profiles):
    days = (PERIOD_END - PERIOD_START).days + 1
    rows, eid = [], 0
    for _, p in providers.iterrows():
        n = int(p.annual_episode_target * 1.5 * rng.uniform(0.9, 1.05))
        # Mild seasonality: more referrals February to May, fewer over summer holidays
        d = PERIOD_START + pd.to_timedelta(rng.integers(0, days, n * 2), "D")
        w = np.where(d.month.isin([2, 3, 4, 5]), 1.25, np.where(d.month.isin([12, 1]), 0.75, 1.0))
        d = pd.DatetimeIndex(rng.choice(d, n, replace=False, p=w / w.sum())).sort_values()
        pr = profiles[p.provider_code]
        for rd in d:
            eid += 1
            youth = p.program_type.startswith("Youth")
            age = (
                rng.choice(["12-17", "18-25"], p=[0.55, 0.45])
                if youth
                else rng.choice(["12-17", "18-25", "26-44", "45-64", "65+"], p=[0.04, 0.2, 0.38, 0.28, 0.1])
            )
            suicide_risk = rng.random() < (0.12 if p.program_type == "Clinical care coordination" else 0.07)
            wait = max(0, int(rng.lognormal(np.log(pr["wait_med"]), 0.7)))
            if suicide_risk:
                fu = pr.get("fu7_2026", pr["fu7"]) if rd >= pd.Timestamp("2026-01-01") else pr["fu7"]
                wait = int(rng.integers(0, 8)) if rng.random() < fu else int(rng.integers(8, 25))
            fc = rd + pd.Timedelta(days=wait)
            engaged = rng.random() > 0.08
            fc_out = pd.NaT if (fc > EXTRACT_DATE or not engaged) else fc
            duration = EPISODE_DAYS[p.program_type]
            planned_end = fc + pd.Timedelta(days=int(rng.gamma(4, duration / 4)))
            fixed = ("fix_from" in pr) and rd >= pr["fix_from"] - pd.Timedelta(days=60)
            close_ok = 0.95 if fixed else pr["close_ok"]
            end_measure = 0.86 if fixed else pr["end_measure"]
            if pd.isna(fc_out):
                status = "Referral not progressed" if not engaged and fc <= EXTRACT_DATE else "Awaiting first contact"
                ed_out = (
                    rd + pd.Timedelta(days=int(rng.integers(30, 90)))
                    if status == "Referral not progressed" and rd + pd.Timedelta(days=90) < EXTRACT_DATE
                    else pd.NaT
                )
                if status == "Referral not progressed" and pd.isna(ed_out):
                    status = "Awaiting first contact"
            elif planned_end <= EXTRACT_DATE and rng.random() < close_ok:
                status = rng.choice(["Treatment concluded", "Client disengaged", "Referred on"], p=[0.72, 0.18, 0.10])
                ed_out = planned_end
            else:
                status, ed_out = "Open", pd.NaT
            rows.append(
                dict(
                    episode_id=f"E{eid:06d}",
                    client_key=f"C{rng.integers(1, 9_000_000):07d}",
                    provider_code=p.provider_code,
                    referral_date=rd.date(),
                    first_contact_date=None if pd.isna(fc_out) else fc_out.date(),
                    episode_end_date=None if pd.isna(ed_out) else ed_out.date(),
                    completion_status=status,
                    suicide_risk_referral="Yes" if suicide_risk else "No",
                    age_group=age,
                    sex=rng.choice(["Female", "Male", "Other/not stated"], p=[0.6, 0.38, 0.02]),
                    indigenous_status=rng.choice(["Aboriginal and/or Torres Strait Islander", "Neither", "Not stated"], p=[0.03, 0.92, 0.05]),
                    iar_level=int(
                        rng.choice([1, 2, 3, 4, 5], p=[0.05, 0.3, 0.35, 0.22, 0.08])
                        if p.program_type != "Clinical care coordination"
                        else rng.choice([3, 4, 5], p=[0.2, 0.5, 0.3])
                    ),
                    x_end_measure=end_measure,
                    x_planned_end=planned_end,
                )
            )
    return pd.DataFrame(rows)


def generate_contacts_and_measures(rng, episodes, providers):
    program = providers.set_index("provider_code").program_type
    contacts, measures, cid, mid = [], [], 0, 0
    for r in episodes.itertuples():
        if r.first_contact_date is None:
            continue
        fc = pd.Timestamp(r.first_contact_date)
        last = pd.Timestamp(r.episode_end_date) if r.episode_end_date else min(EXTRACT_DATE, r.x_planned_end)
        # Stale open episodes: contacts stop well before the extract date
        if r.completion_status == "Open" and r.x_planned_end < EXTRACT_DATE:
            last = r.x_planned_end
        k = max(1, int(rng.poisson(CONTACTS_PER_EPISODE[program[r.provider_code]])))
        span = max(1, (last - fc).days)
        # Distinct contact days: at most one contact per episode per day
        offsets = rng.choice(np.arange(1, span + 1), size=min(k - 1, span), replace=False)
        dates = sorted([fc] + [fc + pd.Timedelta(days=int(x)) for x in offsets])
        for dd in dates:
            if dd > EXTRACT_DATE:
                continue
            cid += 1
            contacts.append(
                dict(
                    contact_id=f"S{cid:07d}",
                    episode_id=r.episode_id,
                    contact_date=dd.date(),
                    modality=rng.choice(["Face to face", "Video", "Telephone"], p=[0.55, 0.3, 0.15]),
                    duration_minutes=int(rng.choice([30, 45, 50, 60], p=[0.2, 0.25, 0.35, 0.2])),
                    attended="Yes" if rng.random() > 0.09 else "No",
                )
            )
        measure = "SDQ" if r.age_group == "12-17" else "K10+"
        lo, hi = SCORE_RANGE[measure]
        base = rng.normal(31, 6) if measure == "K10+" else rng.normal(19, 5)
        if rng.random() < 0.94:
            mid += 1
            measures.append(
                dict(measure_id=f"M{mid:07d}", episode_id=r.episode_id, measure=measure, collection_occasion="Episode start",
                     collection_date=fc.date(), score=round(float(np.clip(base, lo, hi))))
            )
        if r.episode_end_date and r.completion_status != "Referral not progressed" and rng.random() < r.x_end_measure:
            improvement = rng.normal(7, 6) if measure == "K10+" else rng.normal(4, 4)
            if r.completion_status == "Client disengaged":
                improvement *= 0.4
            mid += 1
            measures.append(
                dict(measure_id=f"M{mid:07d}", episode_id=r.episode_id, measure=measure, collection_occasion="Episode end",
                     collection_date=r.episode_end_date, score=round(float(np.clip(base - improvement, lo, hi))))
            )
    return pd.DataFrame(contacts), pd.DataFrame(measures)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default="data/raw/synthetic", help="output folder")
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    rng = np.random.default_rng(SEED)
    providers = PROVIDERS.assign(
        provider_label=PROVIDERS.provider_code + " " + PROVIDERS.program_type, data_source="SYNTHETIC"
    )
    episodes = generate_episodes(rng, providers, behaviour_profiles())
    contacts, measures = generate_contacts_and_measures(rng, episodes, providers)
    episodes = episodes.drop(columns=[c for c in episodes.columns if c.startswith("x_")]).assign(data_source="SYNTHETIC")

    providers.to_csv(out / "dim_provider.csv", index=False)
    SUBREGIONS.to_csv(out / "dim_subregion.csv", index=False)
    SA3_MAP.to_csv(out / "map_sa3_subregion.csv", index=False)
    episodes.to_csv(out / "fact_episode.csv", index=False)
    contacts.to_csv(out / "fact_service_contact.csv", index=False)
    measures.to_csv(out / "fact_outcome_measure.csv", index=False)
    print(f"episodes={len(episodes):,} contacts={len(contacts):,} outcome_measures={len(measures):,} -> {out}")


if __name__ == "__main__":
    main()
