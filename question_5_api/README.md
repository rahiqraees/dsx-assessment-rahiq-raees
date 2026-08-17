# Question 5: Clinical Trial Data API (FastAPI)

A REST API over the ADAE dataset (`data/adae.csv`, exported from R in Question 4).

## Run locally

From the repository root:

```bash
uv sync                                   # one-time: creates .venv with all deps
uv run uvicorn question_5_api.main:app --reload
```

Open http://127.0.0.1:8000/docs for the interactive Swagger UI.
Set `ADAE_CSV_PATH=/path/to/adae.csv` if you want to point it at a different file.

## Endpoints

| Method | Path | What it does |
|---|---|---|
| `GET` | `/` | Welcome message: `{"message": "Clinical Trial Data API is running"}` |
| `POST` | `/ae-query` | Cohort filter by `severity` (list of AESEV values) and/or `treatment_arm` (ACTARM). Missing or null filters are ignored; the filters you do pass are combined with AND. Returns the record count and the unique USUBJIDs. |
| `GET` | `/subject-risk/{subject_id}` | Safety risk score. MILD is 1 point, MODERATE 3, SEVERE 5. Under 5 is Low, 5 to 14 is Medium, 15 or more is High. Returns 404 if the subject has no AE records. |

### Examples

```bash
curl -X POST http://127.0.0.1:8000/ae-query \
  -H 'content-type: application/json' \
  -d '{"severity": ["MILD", "MODERATE"], "treatment_arm": "Placebo"}'

curl http://127.0.0.1:8000/subject-risk/01-701-1015
```

Matching is case-insensitive for both severity and treatment arm. Unknown values
just match no records.

## Layout

- `main.py`: FastAPI app and endpoints (data is loaded once at startup)
- `data.py`: CSV loading and path resolution
- `models.py`: Pydantic request and response schemas
- `risk.py`: pure filtering and scoring logic
- `tests/`: pytest suite (`uv run pytest question_5_api`)
