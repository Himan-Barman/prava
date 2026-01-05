import math

from models import AbuseGraphRequest


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def abuse_score(payload: AbuseGraphRequest) -> float:
    network_risk = payload.network_risk if payload.network_risk is not None else 0.0
    score = (
        -1.0
        + (payload.mutual_blocks * 0.18)
        + (payload.report_count * 0.12)
        + (payload.unique_reporters * 0.22)
        + (network_risk * 0.6)
    )
    return _sigmoid(score)
