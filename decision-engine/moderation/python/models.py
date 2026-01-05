from typing import List, Optional

from pydantic import BaseModel, Field


class ModerationRequest(BaseModel):
    content: str
    language: Optional[str] = None
    content_id: Optional[str] = Field(default=None, alias='contentId')
    user_id: Optional[str] = Field(default=None, alias='userId')


class ModerationResult(BaseModel):
    action: str
    reasons: List[str]
    confidence: float
