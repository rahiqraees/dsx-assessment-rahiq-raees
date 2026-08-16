"""Pydantic request/response models for the Clinical Trial Data API."""

from typing import Literal

from pydantic import BaseModel, Field


class AEQueryRequest(BaseModel):
    """Optional filters for POST /ae-query. Missing or null fields are ignored."""

    severity: list[str] | None = Field(
        default=None,
        description="AE severities to include (AESEV), e.g. ['MILD', 'MODERATE'].",
        examples=[["MILD", "MODERATE"]],
    )
    treatment_arm: str | None = Field(
        default=None,
        description="Actual treatment arm (ACTARM), e.g. 'Placebo'.",
        examples=["Placebo"],
    )


class AEQueryResponse(BaseModel):
    count: int = Field(description="Number of AE records matching all filters.")
    subjects: list[str] = Field(description="Sorted unique USUBJIDs in the cohort.")


class RiskResponse(BaseModel):
    subject_id: str
    risk_score: int
    risk_category: Literal["Low", "Medium", "High"]
