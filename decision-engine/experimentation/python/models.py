from typing import Dict, List, Optional

from pydantic import BaseModel, Field


class FlagRequest(BaseModel):
    user_id: str
    flags: List[str]
    context: Optional[Dict[str, str]] = None


class FlagResponse(BaseModel):
    flags: Dict[str, dict]


class ExperimentAssignRequest(BaseModel):
    user_id: str
    experiment_key: str
    variants: Dict[str, float]
    salt: Optional[str] = None


class ExperimentAssignResponse(BaseModel):
    experiment_key: str
    variant: str
    bucket: float


class RolloutRequest(BaseModel):
    user_id: str
    rollout_key: str
    percentage: float = Field(0.0, ge=0.0, le=1.0)
    salt: Optional[str] = None


class RolloutResponse(BaseModel):
    rollout_key: str
    enabled: bool
    bucket: float
