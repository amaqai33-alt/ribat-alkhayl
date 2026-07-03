# Horse Evaluation Upload Kit

Use these files to prepare data before uploading to cloud.

Recommended formats:
- horses.csv: main horse profile data (easy manual editing in Excel/Sheets)
- evaluations.csv: scoring/evaluation records
- owners.csv: owner information
- horses.json: optional nested/structured data

Rules:
1. Keep IDs unique (horse_id, owner_id, evaluation_id).
2. Dates use ISO format: YYYY-MM-DD.
3. Numeric fields should be numbers only.
4. Keep file names unchanged for easier automation.

Suggested workflow:
1) Fill CSV files first.
2) Validate values and IDs.
3) Upload to cloud storage or import into database.
