import os

import pandas as pd
import pytest

from question_6_genai.agent import ClinicalTrialDataAgent, QueryResult
from question_6_genai.llm import QueryIntent


@pytest.fixture
def df() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "USUBJID": ["01-701-1015", "01-701-1015", "01-701-1023", "01-701-1028"],
            "ACTARM": ["Placebo", "Placebo", "Xanomeline High Dose", "Xanomeline Low Dose"],
            "AESEV": ["MODERATE", "MILD", "MODERATE", "SEVERE"],
            "AETERM": ["HEADACHE", "APPLICATION SITE PRURITUS", "PRURITUS", "SINUS BRADYCARDIA"],
            "AESOC": [
                "NERVOUS SYSTEM DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                "SKIN AND SUBCUTANEOUS TISSUE DISORDERS",
                "CARDIAC DISORDERS",
            ],
            "AEREL": ["NONE", "POSSIBLE", "PROBABLE", "REMOTE"],
        }
    )


def test_execute_exact_match_for_severity(df):
    agent = ClinicalTrialDataAgent(df)
    res = agent.execute(QueryIntent(target_column="AESEV", filter_value="moderate"))
    assert res == QueryResult(
        target_column="AESEV",
        filter_value="moderate",
        count=2,
        subjects=["01-701-1015", "01-701-1023"],
    )


def test_execute_contains_match_for_term_and_soc(df):
    agent = ClinicalTrialDataAgent(df)
    assert agent.execute(QueryIntent(target_column="AETERM", filter_value="pruritus")).subjects == [
        "01-701-1015",
        "01-701-1023",
    ]
    assert agent.execute(QueryIntent(target_column="AESOC", filter_value="cardiac")).subjects == [
        "01-701-1028"
    ]


def test_ask_uses_mock_backend_end_to_end(df, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    agent = ClinicalTrialDataAgent(df)
    assert agent.backend == "mock"
    res = agent.ask("Give me the subjects who had Adverse events of Moderate severity")
    assert (res.target_column, res.filter_value, res.count) == ("AESEV", "MODERATE", 2)
    assert res.subjects == ["01-701-1015", "01-701-1023"]


def test_custom_parse_function_is_used(df):
    agent = ClinicalTrialDataAgent(
        df, parse=lambda q: QueryIntent(target_column="ACTARM", filter_value="Placebo")
    )
    assert agent.ask("anything").count == 2


@pytest.mark.skipif(not os.environ.get("ANTHROPIC_API_KEY"), reason="requires ANTHROPIC_API_KEY")
def test_live_anthropic_backend_parses_severity_question(df):
    agent = ClinicalTrialDataAgent(df)
    assert agent.backend == "anthropic"
    intent = agent.parse("Give me the subjects who had Adverse events of Moderate severity")
    assert intent.target_column == "AESEV"
    assert intent.filter_value.upper() == "MODERATE"
