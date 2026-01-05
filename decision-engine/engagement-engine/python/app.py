from fastapi import FastAPI

from config import load_config
from models import EngagementPrediction, EngagementRequest
from scoring import predict

app = FastAPI(title='Prava Engagement Engine', version='1.0')


@app.get('/health')
def health() -> dict:
    return {'status': 'ok'}


@app.post('/engagement/score')
def score_engagement(payload: EngagementRequest) -> dict:
    cfg = load_config()
    predictions = []

    for candidate in payload.candidates:
        result = predict(candidate, cfg)
        predictions.append(
            EngagementPrediction(
                post_id=candidate.post_id,
                like_prob=result['like_prob'],
                comment_prob=result['comment_prob'],
                share_prob=result['share_prob'],
                dwell_score=result['dwell_score'],
                engagement_score=result['engagement_score'],
            )
        )

    return {
        'user_id': payload.user_id,
        'predictions': [p.model_dump(by_alias=True) for p in predictions],
    }
