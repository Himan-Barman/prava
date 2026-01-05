from collections import deque
from typing import List

from config import RankingConfig
from models import ScoredCandidate


def diversify(
    candidates: List[ScoredCandidate],
    limit: int,
    cfg: RankingConfig,
) -> List[ScoredCandidate]:
    if limit <= 0 or not candidates:
        return []

    remaining = list(candidates)
    selected: List[ScoredCandidate] = []
    recent_authors = deque(maxlen=max(cfg.author_window, 1))
    recent_tags = deque(maxlen=max(cfg.tag_window, 1))
    max_scan = max(cfg.max_scan, 5)

    while remaining and len(selected) < limit:
        best_idx = 0
        best_score = -1.0
        scan = remaining[:max_scan]

        for idx, item in enumerate(scan):
            score = item.score
            if item.candidate.author_id in recent_authors:
                score *= cfg.author_penalty

            if item.candidate.hashtags:
                shared = len(set(item.candidate.hashtags) & set(recent_tags))
                if shared > 0:
                    penalty = max(0.6, 1 - (cfg.tag_penalty * shared))
                    score *= penalty

            if score > best_score:
                best_score = score
                best_idx = idx

        chosen = remaining.pop(best_idx)
        selected.append(chosen)
        recent_authors.append(chosen.candidate.author_id)
        for tag in chosen.candidate.hashtags[:3]:
            if tag:
                recent_tags.append(tag.lower())

    return selected
