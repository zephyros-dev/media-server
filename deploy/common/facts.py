"""Port of roles/common: host facts fed into cue, which generates the application manifests"""

import json
import subprocess

from jinja2 import Environment, FileSystemLoader, StrictUndefined
from pyinfra import host
from pyinfra.facts.server import Command, Home, Hostname, User

from deploy.common.data import REPO

CUE_DIR = REPO / "cue"
CADDYFILE_TEMPLATE = "caddy/Caddyfile.j2"

# roles/common/defaults
DEFAULTS = {
    "caddyfile_host_address": "host.containers.internal",
    "debug": False,
}

_templates = Environment(
    loader=FileSystemLoader(REPO / "roles/application/templates"),
    undefined=StrictUndefined,
    # Ansible's template defaults, plus the template's `#jinja2:lstrip_blocks` header
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)

_cache: dict[str, dict] = {}


def _host_facts() -> dict:
    """The subset of ansible_facts the cue code reads"""
    user = host.get_fact(User)
    return {
        "ansible_facts": {
            "user_id": user,
            "user_uid": int(host.get_fact(Command, "id -u")),
            "user_gid": int(host.get_fact(Command, "id -g")),
            "user_dir": host.get_fact(Home),
            "hostname": host.get_fact(Hostname).split(".")[0],
            "date_time": {"tz": host.get_fact(Command, "date +%Z")},
            "env": {"USER": user},
        },
        # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html
        "nvidia_installed": host.get_fact(
            Command, "/usr/bin/nvidia-smi > /dev/null 2>&1 && echo true || echo false"
        )
        == "true",
    }


def _cue_export(fact: dict) -> dict:
    output = subprocess.run(
        ["cue", "export", ".", "-l", '"factEmbed"', "json:", "-", "--out", "json"],
        cwd=CUE_DIR,
        # Sorted like ansible's to_nice_json, since key order shows up in the generated files
        input=json.dumps(fact, sort_keys=True),
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    result = json.loads(output)
    result.pop("factEmbed")
    return result


def _render_caddyfile(fact: dict, application: dict) -> str:
    source, _, _ = _templates.loader.get_source(_templates, CADDYFILE_TEMPLATE)
    # Ansible reads the `#jinja2:` header line as template options and drops it
    if source.startswith("#jinja2:"):
        source = source.split("\n", 1)[1]
    return _templates.from_string(source).render({**fact, "application": application})


def cue_facts() -> dict:
    """cue output for the current host: `application`, `container_images`, ...

    cue runs twice: the first pass gives the application list the Caddyfile is rendered from,
    the second embeds that Caddyfile into the caddy manifest"""
    if host.name in _cache:
        return _cache[host.name]

    data = host.data.dict()
    fact = {
        **DEFAULTS,
        # pyinfra's connection settings and global arguments aren't vars cue knows about
        **{k: v for k, v in data.items() if not k.startswith(("ssh_", "_"))},
        **_host_facts(),
        "caddyfile_content": "",
    }
    fact["caddyfile_content"] = _render_caddyfile(
        fact, _cue_export(fact)["application"]
    )
    _cache[host.name] = _cue_export(fact)
    return _cache[host.name]
