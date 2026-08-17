"""LLM backends that turn a natural-language question into a structured QueryIntent.

Both implementations share one interface, `invoke(question) -> QueryIntent`:
  * AnthropicLLM uses LangChain's `ChatAnthropic` with structured output. It is
    used when ANTHROPIC_API_KEY is set.
  * MockLLM uses deterministic keyword rules, so the full prompt, parse and
    execute flow runs without any API key.
"""

from __future__ import annotations

import os
import re
from collections.abc import Callable
from typing import Literal

import pandas as pd
from pydantic import BaseModel, Field

from question_6_genai.schema import COLUMN_SCHEMA, build_schema_prompt, distinct_values

MODEL_ID = "claude-opus-5"

ColumnName = Literal["AESEV", "AETERM", "AESOC", "ACTARM", "AEREL", "USUBJID"]


class QueryIntent(BaseModel):
    """Structured output the LLM must produce."""

    target_column: ColumnName = Field(description="The dataset column to filter on.")
    filter_value: str = Field(
        description="The value to search for in that column, extracted from the question "
        "and normalised to the dataset's vocabulary (e.g. 'MODERATE', 'CARDIAC DISORDERS')."
    )


SYSTEM_PROMPT = """You translate a clinical safety reviewer's free-text question about an
adverse-event (AE) dataset into a single structured filter.

{schema}

Rules:
- Pick exactly one target_column that best answers the question.
- Severity/intensity words (mild, moderate, severe) -> AESEV, value upper-case.
- A specific condition, symptom or event name -> AETERM, value upper-case.
- A body system / organ class (cardiac, skin, gastrointestinal, ...) -> AESOC, value upper-case
  MedDRA-style, e.g. "cardiac" -> "CARDIAC DISORDERS".
- Treatment / arm / placebo questions -> ACTARM using the exact allowed value.
- Causality / relationship questions -> AEREL.
- Do not invent columns; do not return explanations."""


class MockLLM:
    """Keyword-based stand-in for the LLM. Deterministic and offline."""

    _SEVERITIES = ("MILD", "MODERATE", "SEVERE")
    _RELATIONS = ("NONE", "REMOTE", "POSSIBLE", "PROBABLE")
    _STOPWORDS = {
        "give",
        "me",
        "the",
        "subjects",
        "subject",
        "patients",
        "patient",
        "who",
        "which",
        "had",
        "have",
        "has",
        "with",
        "of",
        "an",
        "a",
        "any",
        "adverse",
        "events",
        "event",
        "reported",
        "report",
        "list",
        "show",
        "all",
        "that",
        "experienced",
        "please",
        "were",
        "was",
        "on",
        "in",
        "there",
        "are",
        "is",
        "ae",
        "aes",
        "find",
        "get",
        "tell",
        "about",
        "severity",
        "intensity",
        "condition",
        "symptom",
        "cases",
        "case",
        "did",
        "anyone",
        "for",
    }

    def __init__(self, df: pd.DataFrame):
        self._arms = distinct_values(df, "ACTARM") if "ACTARM" in df.columns else []
        self._socs = distinct_values(df, "AESOC") if "AESOC" in df.columns else []

    def invoke(self, question: str) -> QueryIntent:
        text = question.strip()
        upper = text.upper()

        for sev in self._SEVERITIES:  # severity words -> AESEV
            if re.search(rf"\b{sev}\b", upper):
                return QueryIntent(target_column="AESEV", filter_value=sev)

        for arm in self._arms:  # treatment arms -> ACTARM (exact dataset value)
            if arm.upper() in upper:
                return QueryIntent(target_column="ACTARM", filter_value=arm)
        if "PLACEBO" in upper and self._arms:
            return QueryIntent(target_column="ACTARM", filter_value="Placebo")

        for soc in self._socs:  # body systems -> AESOC via the SOC's first word
            # Split on commas as well as spaces. SOCs like 'RESPIRATORY, THORACIC ...'
            # would otherwise give a head of 'RESPIRATORY,' that never matches prose.
            # The trailing \b stops 'EAR' matching 'EARLY' and 'SKIN' matching 'SKINFOLD'.
            head = re.split(r"[\s,]", soc)[0]
            if re.search(rf"\b{re.escape(head)}\b", upper):
                return QueryIntent(target_column="AESOC", filter_value=soc)

        if re.search(r"\b(RELATED|RELATIONSHIP|CAUSALITY)\b", upper):  # causality -> AEREL
            for rel in self._RELATIONS:
                if re.search(rf"\b{rel}\b", upper):
                    return QueryIntent(target_column="AEREL", filter_value=rel)

        # Otherwise treat whatever content words are left as a condition name (AETERM)
        words = [
            w for w in re.findall(r"[A-Za-z][A-Za-z\-']*", text) if w.lower() not in self._STOPWORDS
        ]
        value = " ".join(words).upper() if words else upper
        return QueryIntent(target_column="AETERM", filter_value=value)


class AnthropicLLM:
    """Wrapper around LangChain's ChatAnthropic that returns a QueryIntent via structured output."""

    def __init__(self, df: pd.DataFrame, model: str = MODEL_ID):
        from langchain_anthropic import ChatAnthropic
        from langchain_core.messages import HumanMessage, SystemMessage

        self._system = SYSTEM_PROMPT.format(schema=build_schema_prompt(df))
        self._HumanMessage = HumanMessage
        self._SystemMessage = SystemMessage
        # No `temperature`, this model rejects it. Thinking stays at the model default
        # (adaptive) with low effort. Structured output goes through Anthropic's native
        # `output_config.format` (json_schema mode) rather than a forced tool call, which
        # works alongside thinking and avoids the failure modes of switching it off.
        chat = ChatAnthropic(model=model, max_tokens=1024, output_config={"effort": "low"})
        self._chain = chat.with_structured_output(QueryIntent, method="json_schema")

    def invoke(self, question: str) -> QueryIntent:
        result = self._chain.invoke(
            [self._SystemMessage(content=self._system), self._HumanMessage(content=question)]
        )
        if not isinstance(result, QueryIntent):
            raise ValueError(f"Could not parse question into a QueryIntent: {result!r}")
        return result


def build_llm(df: pd.DataFrame) -> tuple[Callable[[str], QueryIntent], str]:
    """Return (parse_fn, backend_name). Anthropic when a key is present, otherwise the mock."""
    if os.environ.get("ANTHROPIC_API_KEY"):
        return AnthropicLLM(df).invoke, "anthropic"
    return MockLLM(df).invoke, "mock"


__all__ = ["MODEL_ID", "AnthropicLLM", "MockLLM", "QueryIntent", "build_llm", "COLUMN_SCHEMA"]
