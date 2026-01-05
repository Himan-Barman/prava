import math
from datetime import datetime, timezone

from config import RankingConfig
from decay import recency_weight
from models import Candidate


def _to_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def relationship_score(candidate: Candidate, cfg: RankingConfig) -> float:
    if candidate.relationship == 'friend':
        return cfg.friend_score
    if candidate.relationship == 'following':
        return cfg.following_score
    if candidate.relationship == 'followed_by':
        return cfg.followed_by_score
    return cfg.other_score


def engagement_score(candidate: Candidate, cfg: RankingConfig) -> float:
    return (
        math.log1p(candidate.like_count) * cfg.like_weight
        + math.log1p(candidate.comment_count) * cfg.comment_weight
        + math.log1p(candidate.share_count) * cfg.share_weight
    )


def affinity_score(candidate: Candidate, cfg: RankingConfig) -> float:
    affinity = candidate.affinity
    return (
        affinity.likes * cfg.affinity_like_weight
        + affinity.comments * cfg.affinity_comment_weight
        + affinity.shares * cfg.affinity_share_weight
    )


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min_value, min(max_value, value))


def quality_score(candidate: Candidate, cfg: RankingConfig) -> float:
    if candidate.quality_score is not None:
        return _clamp(candidate.quality_score)

    length = max(candidate.text_length, 0)
    if length == 0:
        base = 0.65
    elif length < 30:
        base = 0.82
    elif length < 220:
        base = 1.0
    elif length < 420:
        base = 0.9
    else:
        base = 0.78

    hash_penalty = min(len(candidate.hashtags) * cfg.hashtag_penalty, 0.4)
    mention_penalty = min(len(candidate.mentions) * cfg.mention_penalty, 0.4)
    base = base - hash_penalty - mention_penalty

    if candidate.media_count > 0:
        base += min(candidate.media_count * 0.06, 0.15)

    return _clamp(base)


def safety_multiplier(candidate: Candidate, cfg: RankingConfig) -> float:
    safety = _clamp(candidate.safety_score)
    score = 0.6 + (safety * 0.4)
    if candidate.is_sensitive:
        score *= 0.92
    return _clamp(score, 0.4, 1.1)


def reputation_boost(candidate: Candidate, cfg: RankingConfig) -> float:
    return _clamp(candidate.author_reputation) * cfg.reputation_weight


def negative_penalty(candidate: Candidate, cfg: RankingConfig) -> float:
    return _clamp(candidate.negative_feedback) * cfg.negative_weight


def score_candidate(
    candidate: Candidate,
    cfg: RankingConfig,
    now: datetime,
) -> float:
    created = _to_utc(candidate.created_at)
    now_utc = _to_utc(now)
    age_hours = max((now_utc - created).total_seconds() / 3600.0, 0.0)

    base = (
        relationship_score(candidate, cfg) * cfg.relationship_multiplier
        + engagement_score(candidate, cfg)
        + affinity_score(candidate, cfg)
        + quality_score(candidate, cfg) * cfg.quality_weight
        + candidate.engagement_score * cfg.engagement_weight
        + candidate.interest_score * cfg.interest_weight
        + reputation_boost(candidate, cfg)
    )
    recency = recency_weight(age_hours, cfg.decay_hours)
    freshness = cfg.freshness_boost if age_hours <= cfg.freshness_hours else 0.0

    score = base * recency + freshness
    score *= safety_multiplier(candidate, cfg) * cfg.safety_weight
    score *= max(0.0, 1.0 - negative_penalty(candidate, cfg))

    return max(0.0, score)
