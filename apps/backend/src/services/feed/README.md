# Feed Service

The feed service implements two independent modes:

- `following`: followed accounts plus the viewer's own posts, ordered by recency.
- `for-you`: a ranked hybrid feed using in-network, interacted-author, interest, social-proof, trending, exploration, and cold-start candidates.

## Data Model
Startup migrations in `src/lib/pg.ts` add:

- `feed_events` and `feed_impressions` for impressions, views, dwell, clicks, likes, comments, replies, shares, bookmarks, hides, reports, mutes, blocks, and follow-after-view signals.
- `feed_served_history` to avoid repeated posts within an active session.
- `post_hidden`, `post_not_interested`, and `user_mutes` for hard negative filters.
- `post_topics`, `user_topic_affinities`, and `user_author_affinities` for interest and affinity signals.
- `post_engagement_stats`, `post_trend_snapshots`, and `trending_topics` for quality-adjusted engagement and velocity.
- `feed_algorithm_config` and `feed_experiments` for future tuning and A/B rollout.

## Pipeline
`recommendation.ts` is the modular ranking pipeline:

1. Load ranking config from env and optional DB config.
2. Collect bounded candidates from followed authors, recently interacted authors, topics, social proof, trending posts, exploration, and cold-start popular posts.
3. Deduplicate candidates while retaining all source reasons.
4. Hard-filter blocked, muted, hidden, not-interested, private, deleted, moderated, muted-word, and recently served posts.
5. Hydrate features in batches.
6. Score with `HeuristicScoringProvider`.
7. Apply diversity penalties for repeated authors and topics.
8. Serve with opaque cursors and record served history/impression rows.

## Ranking
The heuristic ranker normalizes these components:

- freshness;
- viewer-author affinity;
- topic/hashtag interest overlap;
- Bayesian-smoothed quality engagement;
- trend velocity;
- social proof from followed users;
- content quality;
- exploration boost;
- negative feedback and spam/report penalties.

Weights are configured with `FEED_WEIGHT_*` env vars or `feed_algorithm_config`.

## APIs
- `GET /api/feed` keeps legacy array responses for current clients.
- `GET /api/feed/for-you` returns `{ items, nextCursor, metrics }`.
- `GET /api/feed/following` returns `{ items, nextCursor, metrics }`.
- `POST /api/feed/events` ingests up to 50 idempotent client events per request.
- `POST /api/feed/:postId/hide`
- `POST /api/feed/:postId/not-interested`

`metrics` should stay internal/admin-oriented. Do not expose score breakdowns publicly unless an authenticated admin tool is added.

## Background Aggregation
`startFeedAggregationScheduler` runs in non-test environments. It:

- syncs hashtags into `post_topics`;
- updates `post_engagement_stats`;
- recomputes user-author and user-topic affinities;
- captures trend snapshots;
- refreshes trending topics;
- prunes old served-history and trend rows.

The first implementation uses PostgreSQL only. Redis can be added later for candidate caches, served-history sets, and trending leaderboards.

## ML Upgrade Path
No ML model is trained or claimed today. Before adding ML, collect enough `feed_impressions` and `feed_events` to build examples:

- positives: long dwell, post open, profile click, like, meaningful comment/reply, share, bookmark, follow-after-view;
- negatives: hide, not interested, report, mute/block after impression, repeated impressions without engagement, rapid skip when tracked.

Future providers can implement the `ScoringProvider` interface:

- embedding similarity retriever;
- two-tower retrieval model;
- learning-to-rank model;
- contextual bandit exploration policy.

Roll out a future ML provider behind an experiment flag and keep `HeuristicScoringProvider` as the fallback.
