import os
from dataclasses import dataclass
from typing import List


def _split_list(value: str | None) -> List[str]:
    if not value:
        return []
    return [item.strip().lower() for item in value.split(',') if item.strip()]


@dataclass(frozen=True)
class ModerationConfig:
    blocklist: List[str]
    review_link_threshold: int
    review_mention_threshold: int
    max_length: int


def load_config() -> ModerationConfig:
    return ModerationConfig(
        blocklist=_split_list(os.getenv('MODERATION_BLOCKLIST')),
        review_link_threshold=int(os.getenv('MOD_LINK_THRESHOLD', '3')),
        review_mention_threshold=int(os.getenv('MOD_MENTION_THRESHOLD', '8')),
        max_length=int(os.getenv('MOD_MAX_LENGTH', '5000')),
    )
