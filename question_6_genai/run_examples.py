"""Example script: run three example questions through ClinicalTrialDataAgent.

Run from the repository root:
    uv run python -m question_6_genai.run_examples
Set ANTHROPIC_API_KEY to use the real LLM; without it a deterministic mock is used.
"""

from __future__ import annotations

import json

from question_5_api.data import load_adae
from question_6_genai.agent import ClinicalTrialDataAgent

EXAMPLE_QUESTIONS = [
    "Give me the subjects who had Adverse events of Moderate severity",
    "Which patients reported a headache?",
    "Show me the subjects with cardiac events",
]


def main() -> None:
    adae = load_adae()
    agent = ClinicalTrialDataAgent(adae)
    n_subjects = adae["USUBJID"].nunique()
    print(f"Backend: {agent.backend}   ({len(adae)} AE records, {n_subjects} subjects)\n")
    for question in EXAMPLE_QUESTIONS:
        intent = agent.parse(question)
        result = agent.execute(intent)
        print(f"Q: {question}")
        print(f"   parsed  -> {json.dumps(intent.model_dump())}")
        print(
            f"   matched -> {result.count} AE records from {len(result.subjects)} subjects; "
            f"first 5: {result.subjects[:5]}\n"
        )


if __name__ == "__main__":
    main()
