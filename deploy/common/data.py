"""Host data from the sops-encrypted group_vars, shared with the ansible playbooks"""

import subprocess
from pathlib import Path

import yaml
from jinja2 import Environment, StrictUndefined

REPO = Path(__file__).resolve().parents[2]
GROUP_VARS = REPO / "group_vars"

_jinja = Environment(undefined=StrictUndefined)


def load_group(group: str) -> dict:
    data = {}
    for path in sorted((GROUP_VARS / group).rglob("*.sops.yaml")):
        decrypted = subprocess.run(
            ["sops", "-d", path], capture_output=True, text=True, check=True
        ).stdout
        data.update(yaml.safe_load(decrypted) or {})
    return data


def _render(value, context: dict):
    if isinstance(value, str) and "{{" in value:
        return _jinja.from_string(value).render(context)
    if isinstance(value, dict):
        return {k: _render(v, context) for k, v in value.items()}
    if isinstance(value, list):
        return [_render(v, context) for v in value]
    return value


def resolve(data: dict) -> dict:
    """Render the jinja references between vars (e.g. wol_config_devices -> wol_bcast_ip),
    the way ansible does lazily"""
    for _ in range(5):
        rendered = _render(data, data)
        if rendered == data:
            return rendered
        data = rendered
    raise ValueError("group_vars jinja references did not settle, is there a cycle?")


def host_data(groups: list[str]) -> dict:
    """Same precedence as ansible group_vars: all, then each group in order"""
    data = {}
    for group in ["all", *groups]:
        data.update(load_group(group))
    return resolve(data)
