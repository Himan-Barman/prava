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
class TrustSafetyConfig:
    trust_base: float = -0.2
    trust_age_weight: float = 0.012
    trust_report_weight: float = -0.08
    trust_block_weight: float = -0.05
    trust_verified_boost: float = 0.4
    trust_quality_weight: float = 0.35
    spam_base: float = -1.0
    spam_link_weight: float = 0.4
    spam_mention_weight: float = 0.3
    spam_duplicate_weight: float = 1.1
    spam_rate_weight: float = 0.25
    shadow_spam_threshold: float = 0.86
    shadow_trust_threshold: float = 0.2


DEFAULTS = TrustSafetyConfig()


def load_config() -> TrustSafetyConfig:
    return TrustSafetyConfig(
        trust_base=_get_float('TS_TRUST_BASE', DEFAULTS.trust_base),
        trust_age_weight=_get_float('TS_TRUST_AGE_WEIGHT', DEFAULTS.trust_age_weight),
        trust_report_weight=_get_float(
            'TS_TRUST_REPORT_WEIGHT',
            DEFAULTS.trust_report_weight,
        ),
        trust_block_weight=_get_float(
            'TS_TRUST_BLOCK_WEIGHT',
            DEFAULTS.trust_block_weight,
        ),
        trust_verified_boost=_get_float(
            'TS_TRUST_VERIFIED_BOOST',
            DEFAULTS.trust_verified_boost,
        ),
        trust_quality_weight=_get_float(
            'TS_TRUST_QUALITY_WEIGHT',
            DEFAULTS.trust_quality_weight,
        ),
        spam_base=_get_float('TS_SPAM_BASE', DEFAULTS.spam_base),
        spam_link_weight=_get_float(
            'TS_SPAM_LINK_WEIGHT',
            DEFAULTS.spam_link_weight,
        ),
        spam_mention_weight=_get_float(
            'TS_SPAM_MENTION_WEIGHT',
            DEFAULTS.spam_mention_weight,
        ),
        spam_duplicate_weight=_get_float(
            'TS_SPAM_DUPLICATE_WEIGHT',
            DEFAULTS.spam_duplicate_weight,
        ),
        spam_rate_weight=_get_float(
            'TS_SPAM_RATE_WEIGHT',
            DEFAULTS.spam_rate_weight,
        ),
        shadow_spam_threshold=_get_float(
            'TS_SHADOW_SPAM_THRESHOLD',
            DEFAULTS.shadow_spam_threshold,
        ),
        shadow_trust_threshold=_get_float(
            'TS_SHADOW_TRUST_THRESHOLD',
            DEFAULTS.shadow_trust_threshold,
        ),
    )
