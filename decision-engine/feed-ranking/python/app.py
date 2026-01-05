from fastapi import FastAPI, HTTPException

from config import load_config
from models import RankRequest, RankResponse
from ranker import rank_feed

app = FastAPI(title='Prava Decision Engine', version='1.0')


@app.get('/health')
def health() -> dict:
    return {'status': 'ok'}


@app.post('/rank/feed', response_model=RankResponse)
def rank_feed_endpoint(payload: RankRequest) -> RankResponse:
    if not payload.candidates:
        return RankResponse(ordered_ids=[], scores={} if payload.debug else None)

    cfg = load_config()
    ordered_ids, scores = rank_feed(payload, cfg)
    return RankResponse(
        ordered_ids=ordered_ids,
        scores=scores if payload.debug else None,
    )
