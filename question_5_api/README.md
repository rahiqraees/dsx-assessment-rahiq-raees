# Question 5 — Clinical Trial Data API (FastAPI)

REST API over the ADAE dataset (`data/adae.csv`, exported from R in Question 4).

## Run locally

From the repository root:

```bash
uv sync                                   # one-time: creates .venv with all deps
uv run uvicorn question_5_api.main:app --reload
```

Open http://127.0.0.1:8000/docs for the interactive Swagger UI.
Set `ADAE_CSV_PATH=/path/to/adae.csv` to point at a different file.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | Welcome message `{"message": "Clinical Trial Data API is running"}` |
| `POST` | `/ae-query` | Dynamic cohort filter by `severity` (list of AESEV) and/or `treatment_arm` (ACTARM). Missing/null filters are ignored; provided filters are ANDed. Returns record count and unique USUBJIDs. |
| `GET` | `/subject-risk/{subject_id}` | Safety risk score: MILD 1, MODERATE 3, SEVERE 5 points; Low < 5, Medium 5–14, High ≥ 15. 404 if the subject has no AE records. |

### Examples

```bash
curl -X POST http://127.0.0.1:8000/ae-query \
  -H 'content-type: application/json' \
  -d '{"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}'

curl http://127.0.0.1:8000/subject-risk/01-701-1015
```

Matching is case-insensitive for both severity and treatment arm; unknown values simply match no records.

## Layout

- `main.py` — FastAPI app and endpoints (data loaded once at startup)
- `data.py` — CSV loading and path resolution
- `models.py` — Pydantic request/response schemas
- `risk.py` — pure filtering and scoring logic
- `tests/` — pytest suite (`uv run pytest question_5_api`)
