"""Host facts fed into cue, which generates the application manifests"""

import json
import subprocess

from pyinfra import host
from pyinfra.facts.server import Command, Home, Hostname, User

from deploy.common.data import REPO
from deploy.common.templates import render

CUE_DIR = REPO / "cue"
CADDYFILE_TEMPLATE = "caddy/Caddyfile.j2"

# Facts cue reads that aren't host data
DEFAULTS = {
    "caddyfile_host_address": "host.containers.internal",
    "debug": False,
}

_cache: dict[str, tuple[dict, dict]] = {}


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
    process = subprocess.run(
        ["cue", "export", ".", "-l", '"factEmbed"', "json:", "-", "--out", "json"],
        cwd=CUE_DIR,
        # Sorted like ansible's to_nice_json, since key order shows up in the generated files
        input=json.dumps(fact, sort_keys=True),
        capture_output=True,
        text=True,
        check=False,
    )
    if process.returncode:
        raise RuntimeError(f"cue export failed:\n{process.stderr}")
    result = json.loads(process.stdout)
    result.pop("factEmbed")
    return result


def _render_caddyfile(fact: dict, application: dict) -> str:
    return render(CADDYFILE_TEMPLATE, {**fact, "application": application})


def _facts() -> tuple[dict, dict]:
    """The facts cue is fed, and its output

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
    _cache[host.name] = (fact, _cue_export(fact))
    return _cache[host.name]


def cue_facts() -> dict:
    """cue output for the current host: `application`, `container_images`, ..."""
    return _facts()[1]


def ansible_vars() -> dict:
    """What the ansible templates see: host data, host facts, then the cue output on top,
    like the ansible role this replaced set the cue output as facts"""
    fact, output = _facts()
    return {**fact, **output, "inventory_hostname": host.name}
