import math
from datetime import datetime, timezone

from config import EngagementConfig
from models import EngagementCandidate


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def _to_hours(created_at: datetime) -> float:
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    age_seconds = (datetime.now(timezone.utc) - created_at).total_seconds()
    return max(age_seconds / 3600.0, 0.0)


def _relationship_boost(candidate: EngagementCandidate, cfg: EngagementConfig) -> float:
    if candidate.relationship == 'friend':
        return cfg.friend_boost
    if candidate.relationship == 'following':
        return cfg.following_boost
    return cfg.other_boost


def _age_penalty(age_hours: float, cfg: EngagementConfig) -> float:
    if cfg.decay_hours <= 0:
        return 0.0
    return -max(age_hours, 0.0) / cfg.decay_hours


def predict(candidate: EngagementCandidate, cfg: EngagementConfig):
    age_hours = candidate.age_hours
    if age_hours <= 0 and candidate.created_at:
        age_hours = _to_hours(candidate.created_at)

    affinity = candidate.affinity
    affinity_score = (
        (affinity.likes + affinity.comments + affinity.shares) * cfg.affinity_weight
    )

    length_score = math.log1p(max(candidate.text_length, 0)) * cfg.length_weight
    media_score = min(candidate.media_count, 3) * cfg.media_weight
    penalty = (
        candidate.hashtag_count * cfg.hashtag_penalty
        + candidate.mention_count * cfg.mention_penalty
    )

    reputation = max(min(candidate.author_reputation, 1.0), 0.0) * cfg.reputation_weight
    base = (
        _relationship_boost(candidate, cfg)
        + affinity_score
        + length_score
        + media_score
        + reputation
        - penalty
        + _age_penalty(age_hours, cfg)
    )

    like_prob = _sigmoid(cfg.base_like + base)
    comment_prob = _sigmoid(cfg.base_comment + base * 0.9)
    share_prob = _sigmoid(cfg.base_share + base * 0.8)
    dwell_score = _sigmoid(cfg.base_dwell + base * 0.6)

    engagement_score = (
        like_prob * 0.45 + comment_prob * 0.3 + share_prob * 0.25
    )

    return {
        'like_prob': like_prob,
        'comment_prob': comment_prob,
        'share_prob': share_prob,
        'dwell_score': dwell_score,
        'engagement_score': engagement_score,
    }
