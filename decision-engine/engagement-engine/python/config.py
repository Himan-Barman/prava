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


@dataclass(frozen=True)
class EngagementConfig:
    base_like: float = -1.2
    base_comment: float = -1.6
    base_share: float = -2.0
    base_dwell: float = -0.6
    friend_boost: float = 0.85
    following_boost: float = 0.6
    other_boost: float = 0.2
    affinity_weight: float = 0.18
    length_weight: float = 0.12
    media_weight: float = 0.25
    hashtag_penalty: float = 0.08
    mention_penalty: float = 0.1
    reputation_weight: float = 0.5
    decay_hours: float = 36.0


DEFAULTS = EngagementConfig()


def load_config() -> EngagementConfig:
    return EngagementConfig(
        base_like=_get_float('ENG_BASE_LIKE', DEFAULTS.base_like),
        base_comment=_get_float('ENG_BASE_COMMENT', DEFAULTS.base_comment),
        base_share=_get_float('ENG_BASE_SHARE', DEFAULTS.base_share),
        base_dwell=_get_float('ENG_BASE_DWELL', DEFAULTS.base_dwell),
        friend_boost=_get_float('ENG_FRIEND_BOOST', DEFAULTS.friend_boost),
        following_boost=_get_float(
            'ENG_FOLLOWING_BOOST',
            DEFAULTS.following_boost,
        ),
        other_boost=_get_float('ENG_OTHER_BOOST', DEFAULTS.other_boost),
        affinity_weight=_get_float('ENG_AFFINITY_WEIGHT', DEFAULTS.affinity_weight),
        length_weight=_get_float('ENG_LENGTH_WEIGHT', DEFAULTS.length_weight),
        media_weight=_get_float('ENG_MEDIA_WEIGHT', DEFAULTS.media_weight),
        hashtag_penalty=_get_float('ENG_HASHTAG_PENALTY', DEFAULTS.hashtag_penalty),
        mention_penalty=_get_float('ENG_MENTION_PENALTY', DEFAULTS.mention_penalty),
        reputation_weight=_get_float(
            'ENG_REPUTATION_WEIGHT',
            DEFAULTS.reputation_weight,
        ),
        decay_hours=_get_float('ENG_DECAY_HOURS', DEFAULTS.decay_hours),
    )
