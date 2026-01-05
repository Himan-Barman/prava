import math

from config import TrustSafetyConfig
from models import SpamScoreRequest


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def spam_score(payload: SpamScoreRequest, cfg: TrustSafetyConfig) -> float:
    score = (
        cfg.spam_base
        + (payload.link_count * cfg.spam_link_weight)
        + (payload.mention_count * cfg.spam_mention_weight)
        + (payload.duplicate_ratio * cfg.spam_duplicate_weight)
        + (payload.post_rate_per_hour * cfg.spam_rate_weight)
    )

    return _sigmoid(score)
