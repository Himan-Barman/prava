import re
from typing import List

from config import ModerationConfig


LINK_PATTERN = re.compile(r'(https?://|www\.)', re.IGNORECASE)
MENTION_PATTERN = re.compile(r'@[a-zA-Z0-9_]{2,32}')
REPEAT_PATTERN = re.compile(r'(.)\1{6,}')


def _match_blocklist(content: str, blocklist: List[str]) -> List[str]:
    lower = content.lower()
    hits = []
    for term in blocklist:
        if term and term in lower:
            hits.append(term)
    return hits


def evaluate_content(content: str, cfg: ModerationConfig):
    reasons: List[str] = []
    action = 'allow'

    if not content.strip():
        return {'action': 'block', 'reasons': ['empty_content'], 'confidence': 0.95}

    blocked = _match_blocklist(content, cfg.blocklist)
    if blocked:
        reasons.append('blocklist_match')
        action = 'block'

    link_count = len(LINK_PATTERN.findall(content))
    mention_count = len(MENTION_PATTERN.findall(content))
    has_repeat = REPEAT_PATTERN.search(content) is not None

    if len(content) > cfg.max_length:
        reasons.append('too_long')
        action = 'review' if action != 'block' else action

    if link_count >= cfg.review_link_threshold:
        reasons.append('excessive_links')
        action = 'review' if action != 'block' else action

    if mention_count >= cfg.review_mention_threshold:
        reasons.append('excessive_mentions')
        action = 'review' if action != 'block' else action

    if has_repeat:
        reasons.append('repeated_chars')
        action = 'review' if action != 'block' else action

    if not reasons:
        return {'action': action, 'reasons': [], 'confidence': 0.15}

    if action == 'block':
        return {'action': action, 'reasons': reasons, 'confidence': 0.92}

    return {'action': action, 'reasons': reasons, 'confidence': 0.6}
