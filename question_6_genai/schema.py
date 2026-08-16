"""Dataset schema shown to the LLM so it can map free-text questions to columns."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import pandas as pd

MatchType = Literal["exact", "contains"]


@dataclass(frozen=True)
class ColumnInfo:
    name: str
    description: str
    match: MatchType  # how the executor compares filter_value with the column


COLUMN_SCHEMA: dict[str, ColumnInfo] = {
    "AESEV": ColumnInfo(
        "AESEV",
        "Severity / intensity of the adverse event. Use for questions about how severe, "
        "serious-sounding, mild, moderate or severe an event was.",
        "exact",
    ),
    "AETERM": ColumnInfo(
        "AETERM",
        "Reported term for the adverse event, i.e. the specific condition or symptom "
        "(headache, nausea, rash, application site pruritus, ...).",
        "contains",
    ),
    "AESOC": ColumnInfo(
        "AESOC",
        "MedDRA primary system organ class, i.e. the body system affected "
        "(cardiac disorders, skin and subcutaneous tissue disorders, "
        "nervous system disorders, ...).",
        "contains",
    ),
    "ACTARM": ColumnInfo(
        "ACTARM",
        "Actual treatment arm the subject received "
        "(Placebo, Xanomeline High Dose, Xanomeline Low Dose).",
        "exact",
    ),
    "AEREL": ColumnInfo(
        "AEREL",
        "Causality / relationship of the event to study drug (NONE, REMOTE, POSSIBLE, PROBABLE).",
        "exact",
    ),
    "USUBJID": ColumnInfo("USUBJID", "Unique subject identifier, e.g. 01-701-1015.", "contains"),
}

# Columns whose full value list is small enough to show to the model verbatim.
ENUMERATED_COLUMNS = ("AESEV", "ACTARM", "AEREL")


def distinct_values(df: pd.DataFrame, column: str, limit: int | None = None) -> list[str]:
    values = sorted(df[column].dropna().astype(str).unique().tolist())
    return values[:limit] if limit else values


def build_schema_prompt(df: pd.DataFrame) -> str:
    """Render the schema (with real values for enumerated columns) as prompt text."""
    lines = ["Columns available in the adverse-event dataset:"]
    for info in COLUMN_SCHEMA.values():
        line = f"- {info.name}: {info.description}"
        if info.name in ENUMERATED_COLUMNS and info.name in df.columns:
            line += f" Allowed values: {', '.join(distinct_values(df, info.name))}."
        elif info.name == "AESOC" and "AESOC" in df.columns:
            line += f" Example values: {', '.join(distinct_values(df, 'AESOC', limit=12))}."
        lines.append(line)
    return "\n".join(lines)
