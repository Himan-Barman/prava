from fastapi import FastAPI

from abuse_graph import abuse_score
from config import load_config
from models import (
    AbuseGraphRequest,
    AbuseGraphResponse,
    ShadowRequest,
    ShadowResponse,
    SpamScoreRequest,
    SpamScoreResponse,
    TrustScoreRequest,
    TrustScoreResponse,
)
from reputation import trust_score
from shadow import should_shadow
from spam import spam_score

app = FastAPI(title='Prava Trust & Safety Engine', version='1.0')


@app.get('/health')
def health() -> dict:
    return {'status': 'ok'}


@app.post('/trust/score', response_model=TrustScoreResponse)
def trust(payload: TrustScoreRequest) -> TrustScoreResponse:
    cfg = load_config()
    return TrustScoreResponse(trust_score=trust_score(payload, cfg))


@app.post('/spam/score', response_model=SpamScoreResponse)
def spam(payload: SpamScoreRequest) -> SpamScoreResponse:
    cfg = load_config()
    return SpamScoreResponse(spam_score=spam_score(payload, cfg))


@app.post('/shadow/evaluate', response_model=ShadowResponse)
def shadow(payload: ShadowRequest) -> ShadowResponse:
    cfg = load_config()
    return ShadowResponse(shadow_ban=should_shadow(payload, cfg))


@app.post('/abuse/score', response_model=AbuseGraphResponse)
def abuse(payload: AbuseGraphRequest) -> AbuseGraphResponse:
    return AbuseGraphResponse(abuse_score=abuse_score(payload))
