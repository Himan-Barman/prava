import json
import os
from dataclasses import dataclass, field
from typing import Dict


@dataclass
class ExperimentConfig:
    flags: Dict[str, dict] = field(default_factory=dict)
    experiments: Dict[str, dict] = field(default_factory=dict)
    rollouts: Dict[str, dict] = field(default_factory=dict)


def _load_from_path(path: str) -> dict:
    with open(path, 'r', encoding='utf-8') as handle:
        return json.load(handle)


def load_config() -> ExperimentConfig:
    raw = {}
    path = os.getenv('EXPERIMENT_CONFIG_PATH')
    inline = os.getenv('EXPERIMENT_CONFIG_JSON')

    if path and os.path.exists(path):
        raw = _load_from_path(path)
    elif inline:
        try:
            raw = json.loads(inline)
        except json.JSONDecodeError:
            raw = {}

    return ExperimentConfig(
        flags=raw.get('flags', {}) if isinstance(raw, dict) else {},
        experiments=raw.get('experiments', {}) if isinstance(raw, dict) else {},
        rollouts=raw.get('rollouts', {}) if isinstance(raw, dict) else {},
    )
