from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class Affinity(BaseModel):
    likes: int = 0
    comments: int = 0
    shares: int = 0


class EngagementCandidate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    post_id: str = Field(alias='postId')
    created_at: Optional[datetime] = Field(default=None, alias='createdAt')
    relationship: Literal['friend', 'following', 'followed_by', 'other'] = 'other'
    text_length: int = Field(default=0, alias='textLength')
    media_count: int = Field(default=0, alias='mediaCount')
    hashtag_count: int = Field(default=0, alias='hashtagCount')
    mention_count: int = Field(default=0, alias='mentionCount')
    age_hours: float = Field(default=0.0, alias='ageHours')
    author_reputation: float = Field(default=0.5, alias='authorReputation')
    affinity: Affinity = Affinity()


class EngagementRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    user_id: str
    candidates: List[EngagementCandidate]
    debug: bool = False


class EngagementPrediction(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    post_id: str = Field(alias='postId')
    like_prob: float = Field(alias='likeProb')
    comment_prob: float = Field(alias='commentProb')
    share_prob: float = Field(alias='shareProb')
    dwell_score: float = Field(alias='dwellScore')
    engagement_score: float = Field(alias='engagementScore')
