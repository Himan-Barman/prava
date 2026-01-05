# Prava Moderation Engine (Python)

Rule-based moderation for posts or messages (block/review/allow).

## Run locally

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 9004
```

## Env tuning (optional)

- `MODERATION_BLOCKLIST` (comma-separated)
- `MOD_LINK_THRESHOLD` (default 3)
- `MOD_MENTION_THRESHOLD` (default 8)
- `MOD_MAX_LENGTH` (default 5000)
