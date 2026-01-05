import math

from config import TrustSafetyConfig
from models import TrustScoreRequest


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def trust_score(payload: TrustScoreRequest, cfg: TrustSafetyConfig) -> float:
    verified = 0.0
    if payload.email_verified:
        verified += 0.2
    if payload.phone_verified:
        verified += 0.2

    score = (
        cfg.trust_base
        + (payload.account_age_days * cfg.trust_age_weight)
        + (payload.quality_score * cfg.trust_quality_weight)
        + (payload.report_count * cfg.trust_report_weight)
        + (payload.block_count * cfg.trust_block_weight)
        + (verified * cfg.trust_verified_boost)
    )

    return _sigmoid(score)
