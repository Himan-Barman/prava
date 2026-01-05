from fastapi import FastAPI

from audit import AuditLog
from config import load_config
from models import ModerationRequest, ModerationResult
from policy import evaluate_content

app = FastAPI(title='Prava Moderation Engine', version='1.0')
audit_log = AuditLog()


@app.get('/health')
def health() -> dict:
    return {'status': 'ok'}


@app.post('/moderation/check', response_model=ModerationResult)
def check_content(payload: ModerationRequest) -> ModerationResult:
    cfg = load_config()
    result = evaluate_content(payload.content, cfg)

    audit_log.record(
        {
            'content_id': payload.content_id,
            'user_id': payload.user_id,
            'action': result['action'],
            'reasons': result['reasons'],
        }
    )

    return ModerationResult(
        action=result['action'],
        reasons=result['reasons'],
        confidence=result['confidence'],
    )


@app.get('/moderation/audit')
def audit(limit: int = 50) -> dict:
    return {'items': audit_log.list_recent(limit)}
