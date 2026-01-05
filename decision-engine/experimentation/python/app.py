from fastapi import FastAPI

from assignment import bucket_for, pick_variant, rollout_decision
from config import load_config
from models import (
    ExperimentAssignRequest,
    ExperimentAssignResponse,
    FlagRequest,
    FlagResponse,
    RolloutRequest,
    RolloutResponse,
)

app = FastAPI(title='Prava Experimentation Engine', version='1.0')


@app.get('/health')
def health() -> dict:
    return {'status': 'ok'}


@app.post('/flags/evaluate', response_model=FlagResponse)
def evaluate_flags(payload: FlagRequest) -> FlagResponse:
    cfg = load_config()
    results = {}

    for name in payload.flags:
        flag = cfg.flags.get(name, {})
        enabled = bool(flag.get('enabled', False))
        rollout = float(flag.get('rollout', 1.0 if enabled else 0.0))
        salt = flag.get('salt')
        bucket = bucket_for(payload.user_id, name, salt)
        active = enabled and rollout_decision(rollout, bucket)

        value = flag.get('value', active)
        variant = None
        if isinstance(flag.get('variants'), dict):
            variant = pick_variant(flag['variants'], bucket)

        results[name] = {
            'enabled': active,
            'value': value,
            'bucket': bucket,
            'variant': variant,
            'reason': 'config',
        }

    return FlagResponse(flags=results)


@app.post('/experiments/assign', response_model=ExperimentAssignResponse)
def assign_experiment(payload: ExperimentAssignRequest) -> ExperimentAssignResponse:
    bucket = bucket_for(payload.user_id, payload.experiment_key, payload.salt)
    variant = pick_variant(payload.variants, bucket)
    return ExperimentAssignResponse(
        experiment_key=payload.experiment_key,
        variant=variant,
        bucket=bucket,
    )


@app.post('/rollouts/evaluate', response_model=RolloutResponse)
def evaluate_rollout(payload: RolloutRequest) -> RolloutResponse:
    bucket = bucket_for(payload.user_id, payload.rollout_key, payload.salt)
    enabled = rollout_decision(payload.percentage, bucket)
    return RolloutResponse(
        rollout_key=payload.rollout_key,
        enabled=enabled,
        bucket=bucket,
    )
