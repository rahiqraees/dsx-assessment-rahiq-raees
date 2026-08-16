import pandas as pd
import pytest
from pydantic import ValidationError

from question_6_genai.llm import MockLLM, QueryIntent, build_llm
from question_6_genai.schema import COLUMN_SCHEMA, build_schema_prompt


@pytest.fixture
def df() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "USUBJID": ["01-701-1015", "01-701-1023"],
            "ACTARM": ["Placebo", "Xanomeline High Dose"],
            "AESEV": ["MODERATE", "MILD"],
            "AETERM": ["HEADACHE", "PRURITUS"],
            "AESOC": ["NERVOUS SYSTEM DISORDERS", "CARDIAC DISORDERS"],
            "AEREL": ["NONE", "POSSIBLE"],
        }
    )


def test_schema_covers_required_columns_and_prompt_lists_values(df):
    assert {"AESEV", "AETERM", "AESOC"} <= set(COLUMN_SCHEMA)
    prompt = build_schema_prompt(df)
    assert "AESEV" in prompt and "MODERATE" in prompt
    assert "AESOC" in prompt and "CARDIAC DISORDERS" in prompt


def test_query_intent_only_accepts_known_columns():
    QueryIntent(target_column="AESEV", filter_value="MILD")
    with pytest.raises(ValidationError):
        QueryIntent(target_column="NOPE", filter_value="x")


@pytest.mark.parametrize(
    "question,column,value",
    [
        ("Give me the subjects who had Adverse events of Moderate severity", "AESEV", "MODERATE"),
        ("Which patients had severe events?", "AESEV", "SEVERE"),
        ("Show subjects with cardiac events", "AESOC", "CARDIAC DISORDERS"),
        ("Who reported a headache?", "AETERM", "HEADACHE"),
        ("List patients on placebo", "ACTARM", "Placebo"),
    ],
)
def test_mock_llm_routes_by_keywords(df, question, column, value):
    intent = MockLLM(df).invoke(question)
    assert intent.target_column == column
    assert intent.filter_value == value


def test_build_llm_falls_back_to_mock_without_key(df, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    parse, backend = build_llm(df)
    assert backend == "mock"
    assert parse("moderate severity").target_column == "AESEV"
