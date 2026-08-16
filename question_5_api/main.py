"""Clinical Trial Data API (Question 5).

Run from the repository root:
    uv run uvicorn question_5_api.main:app --reload
Interactive docs: http://127.0.0.1:8000/docs
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

import pandas as pd
from fastapi import Depends, FastAPI, HTTPException, Request

from question_5_api.data import load_adae
from question_5_api.models import AEQueryRequest, AEQueryResponse, RiskResponse
from question_5_api.risk import compute_risk, query_ae


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Load ADAE once at startup and keep it in app.state."""
    app.state.adae = load_adae()
    yield


app = FastAPI(
    title="Clinical Trial Data API",
    description=(
        "Serves adverse-event data (ADAE), dynamic cohort filtering and subject risk scores."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


def get_adae(request: Request) -> pd.DataFrame:
    """Dependency returning the loaded ADAE frame (overridden in tests)."""
    return request.app.state.adae


@app.get("/", summary="Health check")
def root() -> dict[str, str]:
    return {"message": "Clinical Trial Data API is running"}


@app.post("/ae-query", response_model=AEQueryResponse, summary="Dynamic AE cohort query")
def ae_query(
    body: AEQueryRequest,
    adae: Annotated[pd.DataFrame, Depends(get_adae)],
) -> AEQueryResponse:
    """Filter AEs by severity (AESEV) and/or treatment arm (ACTARM).

    All provided criteria must match; a missing or null field is ignored.
    Returns the number of matching records and the unique subject IDs.
    """
    return query_ae(adae, severity=body.severity, treatment_arm=body.treatment_arm)


@app.get("/subject-risk/{subject_id}", response_model=RiskResponse, summary="Safety risk score")
def subject_risk(
    subject_id: str,
    adae: Annotated[pd.DataFrame, Depends(get_adae)],
) -> RiskResponse:
    """Weighted score: MILD = 1, MODERATE = 3, SEVERE = 5; Low < 5, Medium 5-14, High >= 15."""
    result = compute_risk(adae, subject_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Subject '{subject_id}' not found")
    return result
