"""Loading of the ADAE dataset exported from R (data/adae.csv)."""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ADAE_PATH = REPO_ROOT / "data" / "adae.csv"

REQUIRED_COLUMNS = ("USUBJID", "ACTARM", "AESEV", "AETERM", "AESOC")


def load_adae(path: str | Path | None = None) -> pd.DataFrame:
    """Read adae.csv into a DataFrame.

    Resolution order: explicit `path` argument, `ADAE_CSV_PATH` environment
    variable, then `<repo>/data/adae.csv` (written by
    question_4_tlg/00_export_adae.R).
    """
    csv_path = Path(path or os.environ.get("ADAE_CSV_PATH") or DEFAULT_ADAE_PATH)
    if not csv_path.exists():
        raise FileNotFoundError(
            f"ADAE file not found at {csv_path}. Run "
            "`Rscript question_4_tlg/00_export_adae.R` from the repository root "
            "or set ADAE_CSV_PATH."
        )
    df = pd.read_csv(csv_path, low_memory=False)
    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"ADAE file {csv_path} is missing required columns: {missing}")
    return df
