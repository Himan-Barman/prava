from typing import Optional

from pydantic import BaseModel, Field


class TrustScoreRequest(BaseModel):
    account_age_days: float = Field(0.0, alias='accountAgeDays')
    report_count: int = Field(0, alias='reportCount')
    block_count: int = Field(0, alias='blockCount')
    email_verified: bool = Field(False, alias='emailVerified')
    phone_verified: bool = Field(False, alias='phoneVerified')
    quality_score: float = Field(0.5, alias='qualityScore')


class TrustScoreResponse(BaseModel):
    trust_score: float


class SpamScoreRequest(BaseModel):
    link_count: int = Field(0, alias='linkCount')
    mention_count: int = Field(0, alias='mentionCount')
    duplicate_ratio: float = Field(0.0, alias='duplicateRatio')
    post_rate_per_hour: float = Field(0.0, alias='postRatePerHour')


class SpamScoreResponse(BaseModel):
    spam_score: float


class ShadowRequest(BaseModel):
    trust_score: float = Field(0.5, alias='trustScore')
    spam_score: float = Field(0.0, alias='spamScore')


class ShadowResponse(BaseModel):
    shadow_ban: bool


class AbuseGraphRequest(BaseModel):
    mutual_blocks: int = Field(0, alias='mutualBlocks')
    report_count: int = Field(0, alias='reportCount')
    unique_reporters: int = Field(0, alias='uniqueReporters')
    network_risk: Optional[float] = Field(default=None, alias='networkRisk')


class AbuseGraphResponse(BaseModel):
    abuse_score: float
