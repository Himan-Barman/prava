import os
from dataclasses import dataclass


def _get_float(key: str, default: float) -> float:
    value = os.getenv(key)
    if value is None or value.strip() == '':
        return default
    try:
        return float(value)
    except ValueError:
        return default


def _get_int(key: str, default: int) -> int:
    value = os.getenv(key)
    if value is None or value.strip() == '':
        return default
    try:
        return int(value)
    except ValueError:
        return default


@dataclass(frozen=True)
class RankingConfig:
    friend_score: float = 1.1
    following_score: float = 0.85
    followed_by_score: float = 0.6
    other_score: float = 0.35
    relationship_multiplier: float = 2.1
    like_weight: float = 1.0
    comment_weight: float = 1.5
    share_weight: float = 2.2
    affinity_like_weight: float = 0.35
    affinity_comment_weight: float = 0.6
    affinity_share_weight: float = 0.85
    decay_hours: float = 36.0
    freshness_hours: float = 3.0
    freshness_boost: float = 0.15
    quality_weight: float = 0.5
    engagement_weight: float = 0.7
    interest_weight: float = 0.8
    safety_weight: float = 0.8
    reputation_weight: float = 0.35
    negative_weight: float = 1.2
    hashtag_penalty: float = 0.06
    mention_penalty: float = 0.08
    explore_ratio: float = 0.18
    explore_max: int = 6
    author_window: int = 3
    tag_window: int = 20
    author_penalty: float = 0.55
    tag_penalty: float = 0.08
    max_scan: int = 50


DEFAULTS = RankingConfig()


def load_config() -> RankingConfig:
    return RankingConfig(
        friend_score=_get_float('FEED_FRIEND_SCORE', DEFAULTS.friend_score),
        following_score=_get_float('FEED_FOLLOWING_SCORE', DEFAULTS.following_score),
        followed_by_score=_get_float('FEED_FOLLOWED_BY_SCORE', DEFAULTS.followed_by_score),
        other_score=_get_float('FEED_OTHER_SCORE', DEFAULTS.other_score),
        relationship_multiplier=_get_float(
            'FEED_RELATIONSHIP_MULTIPLIER',
            DEFAULTS.relationship_multiplier,
        ),
        like_weight=_get_float('FEED_LIKE_WEIGHT', DEFAULTS.like_weight),
        comment_weight=_get_float('FEED_COMMENT_WEIGHT', DEFAULTS.comment_weight),
        share_weight=_get_float('FEED_SHARE_WEIGHT', DEFAULTS.share_weight),
        affinity_like_weight=_get_float(
            'FEED_AFFINITY_LIKE_WEIGHT',
            DEFAULTS.affinity_like_weight,
        ),
        affinity_comment_weight=_get_float(
            'FEED_AFFINITY_COMMENT_WEIGHT',
            DEFAULTS.affinity_comment_weight,
        ),
        affinity_share_weight=_get_float(
            'FEED_AFFINITY_SHARE_WEIGHT',
            DEFAULTS.affinity_share_weight,
        ),
        decay_hours=_get_float('FEED_DECAY_HOURS', DEFAULTS.decay_hours),
        freshness_hours=_get_float('FEED_FRESHNESS_HOURS', DEFAULTS.freshness_hours),
        freshness_boost=_get_float('FEED_FRESHNESS_BOOST', DEFAULTS.freshness_boost),
        quality_weight=_get_float('FEED_QUALITY_WEIGHT', DEFAULTS.quality_weight),
        engagement_weight=_get_float(
            'FEED_ENGAGEMENT_WEIGHT',
            DEFAULTS.engagement_weight,
        ),
        interest_weight=_get_float(
            'FEED_INTEREST_WEIGHT',
            DEFAULTS.interest_weight,
        ),
        safety_weight=_get_float('FEED_SAFETY_WEIGHT', DEFAULTS.safety_weight),
        reputation_weight=_get_float(
            'FEED_REPUTATION_WEIGHT',
            DEFAULTS.reputation_weight,
        ),
        negative_weight=_get_float(
            'FEED_NEGATIVE_WEIGHT',
            DEFAULTS.negative_weight,
        ),
        hashtag_penalty=_get_float(
            'FEED_HASHTAG_PENALTY',
            DEFAULTS.hashtag_penalty,
        ),
        mention_penalty=_get_float(
            'FEED_MENTION_PENALTY',
            DEFAULTS.mention_penalty,
        ),
        explore_ratio=_get_float('FEED_EXPLORE_RATIO', DEFAULTS.explore_ratio),
        explore_max=_get_int('FEED_EXPLORE_MAX', DEFAULTS.explore_max),
        author_window=_get_int('FEED_AUTHOR_WINDOW', DEFAULTS.author_window),
        tag_window=_get_int('FEED_TAG_WINDOW', DEFAULTS.tag_window),
        author_penalty=_get_float('FEED_AUTHOR_PENALTY', DEFAULTS.author_penalty),
        tag_penalty=_get_float('FEED_TAG_PENALTY', DEFAULTS.tag_penalty),
        max_scan=_get_int('FEED_MAX_SCAN', DEFAULTS.max_scan),
    )
