"""Group data from the sops-encrypted files in deploy/group_data/<group>/, which the
group_data/<group>.py files pyinfra loads read with `load_group`"""

import subprocess
from pathlib import Path

import yaml
from jinja2 import Environment, StrictUndefined

REPO = Path(__file__).resolve().parents[2]
GROUP_DATA = REPO / "deploy/group_data"

_jinja = Environment(undefined=StrictUndefined)


def _render(value, context: dict):
    if isinstance(value, str) and "{{" in value:
        return _jinja.from_string(value).render(context)
    if isinstance(value, dict):
        return {k: _render(v, context) for k, v in value.items()}
    if isinstance(value, list):
        return [_render(v, context) for v in value]
    return value


def _resolve(data: dict) -> dict:
    """Render the jinja references between values of the group (e.g. wol_config_devices ->
    wol_bcast_ip)"""
    for _ in range(5):
        rendered = _render(data, data)
        if rendered == data:
            return rendered
        data = rendered
    raise ValueError("group data jinja references did not settle, is there a cycle?")


def load_group(group: str) -> dict:
    """The decrypted `deploy/group_data/<group>/**/*.sops.yaml`, files in sorted order.
    Hidden files are skipped: the editor's sops extension keeps a plaintext
    `.decrypted~<name>` copy next to a file while it's open"""
    data = {}
    paths = (GROUP_DATA / group).rglob("*.sops.yaml")
    for path in sorted(p for p in paths if not p.name.startswith(".")):
        decrypted = subprocess.run(
            ["sops", "-d", path], capture_output=True, text=True, check=True
        ).stdout
        data.update(yaml.safe_load(decrypted) or {})
    return _resolve(data)
