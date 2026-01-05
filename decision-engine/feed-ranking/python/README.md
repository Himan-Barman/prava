# Prava Feed Decision Engine (Python)

Lightweight ranking service for the "For you" feed. It scores candidates using
relationship, engagement, affinity, recency decay, plus diversity and exploration.

## Run locally

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 9001
```

## Env tuning (optional)

- `FEED_FRIEND_SCORE`
- `FEED_FOLLOWING_SCORE`
- `FEED_FOLLOWED_BY_SCORE`
- `FEED_OTHER_SCORE`
- `FEED_RELATIONSHIP_MULTIPLIER`
- `FEED_LIKE_WEIGHT`
- `FEED_COMMENT_WEIGHT`
- `FEED_SHARE_WEIGHT`
- `FEED_AFFINITY_LIKE_WEIGHT`
- `FEED_AFFINITY_COMMENT_WEIGHT`
- `FEED_AFFINITY_SHARE_WEIGHT`
- `FEED_DECAY_HOURS`
- `FEED_FRESHNESS_HOURS`
- `FEED_FRESHNESS_BOOST`
- `FEED_QUALITY_WEIGHT`
- `FEED_ENGAGEMENT_WEIGHT`
- `FEED_INTEREST_WEIGHT`
- `FEED_SAFETY_WEIGHT`
- `FEED_REPUTATION_WEIGHT`
- `FEED_NEGATIVE_WEIGHT`
- `FEED_HASHTAG_PENALTY`
- `FEED_MENTION_PENALTY`
- `FEED_EXPLORE_RATIO`
- `FEED_EXPLORE_MAX`
- `FEED_AUTHOR_WINDOW`
- `FEED_TAG_WINDOW`
- `FEED_AUTHOR_PENALTY`
- `FEED_TAG_PENALTY`
- `FEED_MAX_SCAN`

## Payload notes

The `/rank/feed` endpoint accepts optional `variant` (e.g. `social`,
`relevance`, `explore`), plus `engagementScore` and `interestScore` per
candidate to blend engagement predictions and user interest affinity.
