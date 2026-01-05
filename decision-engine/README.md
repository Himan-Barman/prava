# Decision Engine Services

Production-grade Python microservices for feed ranking, engagement prediction,
experimentation, moderation, and trust-safety.

## Services

- Feed Ranking: `decision-engine/feed-ranking/python` (port 9001)
- Engagement: `decision-engine/engagement-engine/python` (port 9002)
- Experimentation: `decision-engine/experimentation/python` (port 9003)
- Moderation: `decision-engine/moderation/python` (port 9004)
- Trust & Safety: `decision-engine/trust-safety/python` (port 9005)

Each service exposes `/health` and module-specific endpoints described in its
own README.

## Backend wiring (optional)

Set the relevant URLs in the backend env:

- `DECISION_ENGINE_URL` -> feed ranking (used by `/feed?mode=for-you`)
- `ENGAGEMENT_ENGINE_URL`
- `EXPERIMENTATION_ENGINE_URL`
- `MODERATION_ENGINE_URL`
- `TRUST_SAFETY_ENGINE_URL`

Only `DECISION_ENGINE_URL` is used right now; the others are ready for
incremental integration.
