from config import TrustSafetyConfig
from models import ShadowRequest


def should_shadow(payload: ShadowRequest, cfg: TrustSafetyConfig) -> bool:
    if payload.spam_score >= cfg.shadow_spam_threshold:
        return True
    if payload.trust_score <= cfg.shadow_trust_threshold:
        return True
    return False
