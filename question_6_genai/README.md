# Question 6: GenAI Clinical Data Assistant (LLM and LangChain)

Turns a free-text question from a clinical safety reviewer into a structured
pandas filter over the AE dataset (`data/adae.csv`), without hard-coding any
question patterns.

## Flow

```
question --> ClinicalTrialDataAgent.parse --> QueryIntent{target_column, filter_value}
                  (LLM via LangChain)                       |
                                                            v
             ClinicalTrialDataAgent.execute --> pandas filter --> {count, subjects}
```

1. **Schema definition** (`schema.py`). `COLUMN_SCHEMA` describes AESEV, AETERM,
   AESOC, ACTARM, AEREL and USUBJID for the model, and `build_schema_prompt()`
   puts the real allowed values from the CSV into the system prompt.
2. **LLM implementation** (`llm.py`). `ChatAnthropic` (model `claude-opus-5`, low
   effort) with `with_structured_output(QueryIntent, method="json_schema")`, so
   the model has to return JSON matching `{target_column, filter_value}`. If
   `ANTHROPIC_API_KEY` is not set, a deterministic `MockLLM` with the same
   interface is used instead, so the full prompt, parse and execute flow still
   runs.
3. **Execution** (`agent.py`). Exact, case-insensitive match for enumerated
   columns (AESEV, ACTARM, AEREL) and partial match for free-text columns
   (AETERM, AESOC) and for USUBJID. Returns the number of matching AE records
   (`count`) and the sorted list of unique USUBJIDs (`subjects`).

## Run

```bash
uv sync
export ANTHROPIC_API_KEY=...             # optional; leave it out to use the mock backend
uv run python -m question_6_genai.run_examples
```

Example questions in the test script:

- "Give me the subjects who had Adverse events of Moderate severity" -> `AESEV = MODERATE`
- "Which patients reported a headache?" -> `AETERM contains HEADACHE`
- "Show me the subjects with cardiac events" -> `AESOC contains CARDIAC DISORDERS`

## Tests

```bash
uv run pytest question_6_genai            # mock backend; the live test skips itself when there is no key
```
