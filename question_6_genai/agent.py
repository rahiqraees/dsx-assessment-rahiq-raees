"""ClinicalTrialDataAgent: natural-language question -> structured intent -> pandas filter."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

import pandas as pd

from question_6_genai.llm import QueryIntent, build_llm
from question_6_genai.schema import COLUMN_SCHEMA


@dataclass
class QueryResult:
    target_column: str
    filter_value: str
    count: int  # matching AE records
    subjects: list[str] = field(default_factory=list)


class ClinicalTrialDataAgent:
    """Prompt -> Parse -> Execute.

    parse   : ask the LLM (or the mock) which column/value the question refers to
    execute : apply that filter to the AE DataFrame and return matching subjects
    """

    def __init__(self, df: pd.DataFrame, parse: Callable[[str], QueryIntent] | None = None):
        self.df = df
        if parse is None:
            parse, backend = build_llm(df)
        else:
            backend = "custom"
        self._parse = parse
        self.backend = backend

    # -- Parse -----------------------------------------------------------------
    def parse(self, question: str) -> QueryIntent:
        return self._parse(question)

    # -- Execute ---------------------------------------------------------------
    def execute(self, intent: QueryIntent) -> QueryResult:
        column = intent.target_column
        if column not in self.df.columns:
            raise KeyError(f"Column {column!r} is not present in the dataset")
        series = self.df[column].astype(str).str.upper()
        value = intent.filter_value.strip().upper()
        if COLUMN_SCHEMA[column].match == "exact":
            mask = series == value
        else:  # "contains": partial, case-insensitive match
            mask = series.str.contains(value, regex=False, na=False)
        subjects = sorted(self.df.loc[mask, "USUBJID"].dropna().astype(str).unique().tolist())
        return QueryResult(
            target_column=column,
            filter_value=intent.filter_value,
            count=int(mask.sum()),
            subjects=subjects,
        )

    # -- Prompt -> Parse -> Execute -------------------------------------------
    def ask(self, question: str) -> QueryResult:
        return self.execute(self.parse(question))
