"""Pure data logic for the API: cohort filtering and safety risk scoring."""

from __future__ import annotations

import pandas as pd

from question_5_api.models import AEQueryResponse, RiskResponse

# Weighted points per AE severity (AESEV).
SEVERITY_POINTS: dict[str, int] = {"MILD": 1, "MODERATE": 3, "SEVERE": 5}


def severity_points(aesev: object) -> int:
    """Points for one AE. Unknown or missing severities count 0."""
    if aesev is None or pd.isna(aesev):
        return 0
    return SEVERITY_POINTS.get(str(aesev).strip().upper(), 0)


def risk_category(score: int) -> str:
    """Low: < 5, Medium: 5 <= score < 15, High: >= 15."""
    if score < 5:
        return "Low"
    if score < 15:
        return "Medium"
    return "High"


def compute_risk(df: pd.DataFrame, subject_id: str) -> RiskResponse | None:
    """Sum severity points over a subject's AEs. Returns None if the subject has no records."""
    subject_aes = df[df["USUBJID"] == subject_id]
    if subject_aes.empty:
        return None
    score = int(subject_aes["AESEV"].map(severity_points).sum())
    return RiskResponse(subject_id=subject_id, risk_score=score, risk_category=risk_category(score))


def query_ae(
    df: pd.DataFrame, severity: list[str] | None, treatment_arm: str | None
) -> AEQueryResponse:
    """Filter AE records. Every filter that is given must match; null or empty ones are ignored."""
    mask = pd.Series(True, index=df.index)
    if severity:  # None or [] means no severity filter
        wanted = {s.strip().upper() for s in severity}
        mask &= df["AESEV"].astype(str).str.upper().isin(wanted)
    if treatment_arm is not None and treatment_arm.strip() != "":
        mask &= df["ACTARM"].astype(str).str.casefold() == treatment_arm.strip().casefold()
    matched = df[mask]
    subjects = sorted(matched["USUBJID"].dropna().astype(str).unique().tolist())
    return AEQueryResponse(count=int(len(matched)), subjects=subjects)
