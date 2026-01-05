import math


def recency_weight(age_hours: float, decay_hours: float) -> float:
    if decay_hours <= 0:
        return 1.0
    return math.exp(-max(age_hours, 0.0) / decay_hours)
