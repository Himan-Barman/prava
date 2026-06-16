# Feed Service

The feed service is a PostgreSQL-first recommendation subsystem for Prava's text-first social graph. It keeps the existing mobile-compatible `/api/feed` routes while adding production feed modes, feed controls, saved custom feeds, stable sessions, and explainable recommendation metadata.

## Request Flow

1. Authenticate with the shared `requireAuth` middleware.
2. Resolve feed mode, lens, cursor, page size, session ID, preferences, and user controls.
3. Retrieve bounded candidates from multiple sources.
4. Deduplicate candidates while retaining source reason codes.
5. Hydrate relationship, topic, engagement, impression, and quality features.
6. Apply hard filters for deletion, moderation, blocking, muting, hidden/not-interested posts, muted words, muted/snoozed topics, sensitive content, repost controls, and out-of-network quality gates.
7. Score candidates with the configurable heuristic ranker.
8. Re-rank for author/topic diversity and repetition control.
9. Persist a short feed-session snapshot and served-history rows.
10. Return hydrated posts with compact explanation metadata.

## Feed Modes

- `for-you`: mixed personalized ranking from followed accounts, friends, trusted network engagement, interests, trends, language affinity, conversations, fresh voices, editorial items, exploration, and cold start.
- `following`: deterministic reverse chronological followed/self timeline with safety and privacy filters only.
- `friends`: reverse chronological mutual-follow timeline.
- `latest`: reverse chronological network or broad scope.
- `topics`: topic/hashtag timeline.
- `conversations`: active discussion and reply-heavy posts.
- `explore`: discovery-heavy For You variant with stricter out-of-network quality checks.
- `catch-up`: important followed/topic/conversation posts since the viewer's last active feed impression.
- `custom`: saved server-validated feed presets.

## Candidate Sources

Implemented sources include network recent, friend recent, interacted authors, topic affinity, trusted network/social proof, trending, exploration, emerging creators, conversation, language affinity, editorial, and cold start. Semantic and model-backed retrieval remain behind the `ScoringProvider` boundary for a later ML rollout.

## Ranking

`HeuristicScoringProvider` scores:

- recency
- viewer-author affinity
- friend/follow proximity
- topic and language affinity
- quality-adjusted engagement
- trend velocity
- social proof
- content quality
- exploration/new-creator value
- conversation value
- editorial labeling
- negative feedback, reports, spam, toxicity, clickbait, repeated serving, and repetition penalties

Weights are centralized in `DEFAULT_CONFIG`, environment overrides, and optional `feed_algorithm_config`.

## User Controls

APIs support:

- why am I seeing this post
- show more / show fewer
- not interested
- hide post
- follow/unfollow topic
- mute topic
- snooze topic
- reduce reposts
- reduce sensitive content
- preferred lens
- discovery intensity
- friend/latest priority
- preferred languages
- muted keywords
- review/remove inferred interests
- reset personalization
- clear served history
- export feed settings
- save/update/delete custom feeds

## Database

Startup migrations add or repair:

- post feature columns: type, parent/original/quote IDs, fingerprint, visibility, sensitivity, spam/toxicity/clickbait scores.
- `topics`
- `user_followed_topics`
- `feed_muted_topics`
- `feed_preferences`
- `feed_custom_feeds`
- `feed_sessions`
- `feed_feedback`
- `editorial_feed_items`
- existing ranking tables: `feed_events`, `feed_impressions`, `feed_served_history`, `post_topics`, `user_topic_affinities`, `user_author_affinities`, `post_engagement_stats`, `post_trend_snapshots`, `trending_topics`, `feed_algorithm_config`, `feed_experiments`.

Default admin-curated topic seeds include technology, startups, coding, careers, sports, entertainment, education, local news, art, literature, and Bengali literature.

## API Routes

Legacy feed routes:

- `GET /api/feed`
- `GET /api/feed/for-you`
- `GET /api/feed/following`
- `GET /api/feed/friends`
- `GET /api/feed/latest`
- `GET /api/feed/explore`
- `GET /api/feed/conversations`
- `GET /api/feed/catch-up`
- `GET /api/feed/topic/:topic`
- `GET /api/feed/custom/:feedId`
- `GET /api/feed/topics`
- `POST /api/feed/topics/:topic/follow`
- `DELETE /api/feed/topics/:topic/follow`
- `POST /api/feed/topics/:topic/mute`
- `DELETE /api/feed/topics/:topic/mute`
- `POST /api/feed/topics/:topic/snooze`
- `GET /api/feed/preferences`
- `PATCH /api/feed/preferences`
- `POST /api/feed/preferences/reset`
- `GET /api/feed/preferences/export`
- `GET /api/feed/interests`
- `DELETE /api/feed/interests/:topic`
- `POST /api/feed/history/clear`
- `GET /api/feed/custom-feeds`
- `POST /api/feed/custom-feeds`
- `PATCH /api/feed/custom-feeds/:feedId`
- `DELETE /api/feed/custom-feeds/:feedId`
- `POST /api/feed/events`
- `POST /api/feed/:postId/show-more`
- `POST /api/feed/:postId/show-fewer`
- `GET /api/feed/:postId/why`
- existing post/comment/like/share routes.

V1 bridge routes mirror these under `/api/v1/feed/*` and `/api/v1/posts/:postId/*`.

## Background Jobs

`startFeedAggregationScheduler` runs in non-test environments. It:

- syncs hashtags into `post_topics`
- updates `post_engagement_stats`
- recomputes author/topic affinity
- captures trend snapshots
- refreshes trending topics
- prunes served-history and trend snapshots

Developer-only route `POST /api/feed/aggregate` triggers aggregation outside production.

## Redis

No new hard Redis dependency is introduced in this pass. Redis remains available for future candidate caches, session caches, sorted-set trend windows, and stream-style worker fanout. Current behavior degrades to PostgreSQL only.

Suggested future keys:

- `feed:candidates:{userId}:{mode}:{lens}`
- `feed:session:{sessionId}`
- `feed:served:{userId}`
- `feed:trending:{window}:{language}:{region}`

## Scaling Path

At 100k users, PostgreSQL plus bounded candidate queries, indexes, and background aggregation are practical.

At 1M users, move hot candidate sets, served-history checks, and trend windows into Redis sorted sets or streams; increase worker partitioning; precompute followed/friends timelines for normal accounts.

At 10M users, add partitioned feed event tables, fanout-on-write for normal accounts, fanout-on-read for large creators, vector/ANN retrieval behind the semantic adapter, and offline-trained ranking models behind `ScoringProvider`.

## Current Tradeoffs

- Ranking is heuristic, not ML-trained.
- Semantic retrieval is interface-ready but not backed by pgvector or an external vector store.
- Redis trend windows are documented but not required for runtime yet.
- Editorial/sponsored labeling exists; sponsored delivery itself is not implemented.
- Local discovery is gated by preferences but does not yet perform regional ranking without a location pipeline.

## Validation

Run:

```bash
npm run typecheck
npm test
```

The feed tests cover candidate mixing, Following chronology, Friends/Topic/Custom modes, explanations, invalid cursor rejection, not-interested filtering, and event idempotency.
