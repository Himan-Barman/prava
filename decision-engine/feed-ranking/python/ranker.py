from dataclasses import replace
from datetime import datetime, timezone
from typing import Dict, List, Tuple

from config import RankingConfig
from diversity import diversify
from exploration import allocate_explore_slots, interleave, split_candidates
from models import RankRequest, ScoredCandidate
from scoring import score_candidate


VARIANT_PRESETS = {
    'social': {
        'relationship_multiplier': 2.7,
        'explore_ratio': 0.12,
        'author_window': 4,
    },
    'relevance': {
        'engagement_weight': 0.9,
        'quality_weight': 0.7,
        'explore_ratio': 0.16,
    },
    'explore': {
        'explore_ratio': 0.3,
        'freshness_boost': 0.22,
        'relationship_multiplier': 1.7,
    },
}


def apply_variant(cfg: RankingConfig, variant: str | None) -> RankingConfig:
    if not variant:
        return cfg
    preset = VARIANT_PRESETS.get(variant.lower())
    if not preset:
        return cfg
    return replace(cfg, **preset)


def _score_candidates(
    request: RankRequest,
    cfg: RankingConfig,
) -> Tuple[List[ScoredCandidate], Dict[str, float]]:
    now = datetime.now(timezone.utc)
    scored: List[ScoredCandidate] = []
    scores: Dict[str, float] = {}

    for candidate in request.candidates:
        score = score_candidate(candidate, cfg, now)
        scored.append(ScoredCandidate(candidate=candidate, score=score))
        scores[candidate.post_id] = score

    scored.sort(key=lambda item: item.score, reverse=True)
    return scored, scores


def rank_feed(request: RankRequest, cfg: RankingConfig) -> Tuple[List[str], Dict[str, float]]:
    cfg = apply_variant(cfg, request.variant)
    scored, scores = _score_candidates(request, cfg)
    if request.limit <= 0:
        return [], scores

    if request.mode == 'following':
        scored.sort(key=lambda item: item.candidate.created_at, reverse=True)
        ranked = diversify(scored, request.limit, cfg)
        return [item.candidate.post_id for item in ranked], scores

    primary, explore = split_candidates(scored)
    explore_slots = allocate_explore_slots(request.limit, explore, cfg)
    primary_limit = max(request.limit - explore_slots, 0)

    ranked_primary = diversify(primary, primary_limit, cfg)
    ranked_explore = diversify(explore, explore_slots, cfg)
    final = interleave(ranked_primary, ranked_explore, request.limit)

    return [item.candidate.post_id for item in final], scores
