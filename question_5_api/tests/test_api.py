import pandas as pd
import pytest
from fastapi.testclient import TestClient

from question_5_api.main import app, get_adae


@pytest.fixture
def client(adae_small: pd.DataFrame):
    app.dependency_overrides[get_adae] = lambda: adae_small
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_root_welcome(client):
    r = client.get("/")
    assert r.status_code == 200
    assert r.json() == {"message": "Clinical Trial Data API is running"}


def test_ae_query_with_both_filters(client):
    r = client.post(
        "/ae-query", json={"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}
    )
    assert r.status_code == 200
    assert r.json() == {"count": 2, "subjects": ["01-701-1015"]}


def test_ae_query_missing_and_null_filters_are_ignored(client):
    assert client.post("/ae-query", json={}).json()["count"] == 6
    assert (
        client.post("/ae-query", json={"severity": None, "treatment_arm": None}).json()["count"]
        == 6
    )
    r = client.post("/ae-query", json={"treatment_arm": "Xanomeline Low Dose"})
    assert r.json() == {"count": 1, "subjects": ["01-701-1028"]}


def test_ae_query_rejects_wrong_types(client):
    r = client.post("/ae-query", json={"severity": "MILD"})  # must be a list
    assert r.status_code == 422


def test_subject_risk_known_subject(client):
    r = client.get("/subject-risk/01-701-1015")
    assert r.status_code == 200
    assert r.json() == {"subject_id": "01-701-1015", "risk_score": 9, "risk_category": "Medium"}


def test_subject_risk_unknown_subject_404(client):
    r = client.get("/subject-risk/99-999-9999")
    assert r.status_code == 404
    assert r.json()["detail"] == "Subject '99-999-9999' not found"
