# Prava Engagement Engine (Python)

Predicts engagement probabilities for feed candidates (like, comment, share, dwell).

## Run locally

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 9002
```

## Env tuning (optional)

- `ENG_BASE_LIKE`
- `ENG_BASE_COMMENT`
- `ENG_BASE_SHARE`
- `ENG_BASE_DWELL`
- `ENG_FRIEND_BOOST`
- `ENG_FOLLOWING_BOOST`
- `ENG_OTHER_BOOST`
- `ENG_AFFINITY_WEIGHT`
- `ENG_LENGTH_WEIGHT`
- `ENG_MEDIA_WEIGHT`
- `ENG_HASHTAG_PENALTY`
- `ENG_MENTION_PENALTY`
- `ENG_REPUTATION_WEIGHT`
- `ENG_DECAY_HOURS`
