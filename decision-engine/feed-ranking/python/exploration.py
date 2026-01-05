from typing import List, Tuple

from config import RankingConfig
from models import ScoredCandidate


def split_candidates(
    candidates: List[ScoredCandidate],
) -> Tuple[List[ScoredCandidate], List[ScoredCandidate]]:
    primary = [item for item in candidates if item.candidate.relationship != 'other']
    explore = [item for item in candidates if item.candidate.relationship == 'other']
    return primary, explore


def allocate_explore_slots(
    limit: int,
    explore_candidates: List[ScoredCandidate],
    cfg: RankingConfig,
) -> int:
    if limit <= 0 or not explore_candidates:
        return 0

    raw = int(round(limit * cfg.explore_ratio))
    slots = max(1, raw) if limit >= 4 else min(raw, 1)
    slots = min(slots, cfg.explore_max, len(explore_candidates))
    slots = min(slots, max(limit - 1, 0))
    return slots


def interleave(
    primary: List[ScoredCandidate],
    explore: List[ScoredCandidate],
    limit: int,
) -> List[ScoredCandidate]:
    if limit <= 0:
        return []
    if not explore:
        return primary[:limit]
    if not primary:
        return explore[:limit]

    result: List[ScoredCandidate] = []
    explore_slots = min(len(explore), limit)
    gap = max(1, len(primary) // (explore_slots + 1))
    primary_idx = 0
    explore_idx = 0

    while len(result) < limit and (primary_idx < len(primary) or explore_idx < len(explore)):
        for _ in range(gap):
            if primary_idx >= len(primary) or len(result) >= limit:
                break
            result.append(primary[primary_idx])
            primary_idx += 1

        if explore_idx < len(explore) and len(result) < limit:
            result.append(explore[explore_idx])
            explore_idx += 1

        if primary_idx >= len(primary) and explore_idx < len(explore):
            while explore_idx < len(explore) and len(result) < limit:
                result.append(explore[explore_idx])
                explore_idx += 1

    return result[:limit]
