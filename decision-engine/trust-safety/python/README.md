# Prava Trust & Safety Engine (Python)

Computes trust, spam, and abuse scores plus shadow-ban decisions.

## Run locally

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 9005
```

## Env tuning (optional)

- `TS_TRUST_BASE`
- `TS_TRUST_AGE_WEIGHT`
- `TS_TRUST_REPORT_WEIGHT`
- `TS_TRUST_BLOCK_WEIGHT`
- `TS_TRUST_VERIFIED_BOOST`
- `TS_TRUST_QUALITY_WEIGHT`
- `TS_SPAM_BASE`
- `TS_SPAM_LINK_WEIGHT`
- `TS_SPAM_MENTION_WEIGHT`
- `TS_SPAM_DUPLICATE_WEIGHT`
- `TS_SPAM_RATE_WEIGHT`
- `TS_SHADOW_SPAM_THRESHOLD`
- `TS_SHADOW_TRUST_THRESHOLD`
