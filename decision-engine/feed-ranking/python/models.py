from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class Affinity(BaseModel):
    likes: int = 0
    comments: int = 0
    shares: int = 0


class Candidate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    post_id: str = Field(alias='postId')
    author_id: str = Field(alias='authorId')
    created_at: datetime = Field(alias='createdAt')
    like_count: int = Field(default=0, alias='likeCount')
    comment_count: int = Field(default=0, alias='commentCount')
    share_count: int = Field(default=0, alias='shareCount')
    text_length: int = Field(default=0, alias='textLength')
    media_count: int = Field(default=0, alias='mediaCount')
    engagement_score: float = Field(default=0.0, alias='engagementScore')
    interest_score: float = Field(default=0.0, alias='interestScore')
    language: Optional[str] = None
    author_reputation: float = Field(default=0.5, alias='authorReputation')
    safety_score: float = Field(default=1.0, alias='safetyScore')
    quality_score: Optional[float] = Field(default=None, alias='qualityScore')
    negative_feedback: float = Field(default=0.0, alias='negativeFeedback')
    is_sensitive: bool = Field(default=False, alias='isSensitive')
    relationship: Literal[
        'friend',
        'following',
        'followed_by',
        'other',
    ] = 'other'
    affinity: Affinity = Affinity()
    hashtags: List[str] = []
    mentions: List[str] = []


class RankRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    user_id: str
    limit: int = Field(20, ge=1, le=200)
    mode: Literal['for-you', 'following'] = 'for-you'
    candidates: List[Candidate] = Field(default_factory=list)
    variant: Optional[str] = None
    debug: bool = False


class RankResponse(BaseModel):
    ordered_ids: List[str]
    scores: Optional[Dict[str, float]] = None


@dataclass
class ScoredCandidate:
    candidate: Candidate
    score: float
