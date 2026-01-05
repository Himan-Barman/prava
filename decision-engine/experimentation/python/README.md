# Prava Experimentation Engine (Python)

Deterministic feature flags, rollouts, and A/B assignment.

## Run locally

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 9003
```

## Config

Provide either:
- `EXPERIMENT_CONFIG_PATH` pointing to a JSON file, or
- `EXPERIMENT_CONFIG_JSON` with inline JSON.

Example JSON:

```json
{
  "flags": {
    "new_feed": { "enabled": true, "rollout": 0.5, "value": true }
  },
  "experiments": {
    "feed_algo": { "variants": { "control": 0.5, "treatment": 0.5 } }
  },
  "rollouts": {
    "premium_banner": { "rollout": 0.2 }
  }
}
```
