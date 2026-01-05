from collections import deque
from datetime import datetime, timezone
from typing import Deque, Dict, List


class AuditLog:
    def __init__(self, max_items: int = 200):
        self._items: Deque[Dict[str, object]] = deque(maxlen=max_items)

    def record(self, entry: Dict[str, object]) -> None:
        payload = dict(entry)
        payload['timestamp'] = datetime.now(timezone.utc).isoformat()
        self._items.appendleft(payload)

    def list_recent(self, limit: int = 50) -> List[Dict[str, object]]:
        return list(self._items)[:limit]
