import hashlib
from typing import Dict, Tuple


def _hash_bucket(value: str) -> float:
    digest = hashlib.sha256(value.encode('utf-8')).hexdigest()
    max_int = int('f' * 64, 16)
    return int(digest, 16) / max_int


def bucket_for(user_id: str, key: str, salt: str | None = None) -> float:
    seed = f'{user_id}:{key}:{salt or ""}'
    return _hash_bucket(seed)


def pick_variant(variants: Dict[str, float], bucket: float) -> str:
    if not variants:
        return 'control'

    total = sum(max(weight, 0.0) for weight in variants.values())
    if total <= 0:
        return next(iter(variants.keys()))

    threshold = bucket * total
    running = 0.0
    for name, weight in variants.items():
        running += max(weight, 0.0)
        if threshold <= running:
            return name

    return next(reversed(variants.keys()))


def rollout_decision(percentage: float, bucket: float) -> bool:
    return bucket <= max(min(percentage, 1.0), 0.0)
