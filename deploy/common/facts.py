"""Host facts fed into cue, which generates the application manifests"""

import json
import subprocess

from pyinfra import host
from pyinfra.facts.server import Command, Hostname, User, Users

from deploy.common.data import REPO
from deploy.common.templates import caddy_password_hash, render

CUE_DIR = REPO / "deploy/cue"
CADDYFILE_TEMPLATE = "caddy/Caddyfile.j2"

# Facts cue reads that aren't host data
DEFAULTS = {
    "caddyfile_host_address": "host.containers.internal",
    "debug": False,
}

_cache: dict[str, tuple[dict, dict]] = {}


def _host_facts() -> dict:
    """The host facts the cue code and templates read, as `host`, named after the pyinfra
    facts they come from"""
    user = host.get_fact(User)
    account = host.get_fact(Users)[user]
    return {
        "host": {
            # The inventory name, e.g. server.lan
            "name": host.name,
            "hostname": host.get_fact(Hostname).split(".")[0],
            "user": user,
            "uid": account["uid"],
            "gid": account["gid"],
            "home": account["home"],
            # pyinfra has no timezone fact
            "timezone": host.get_fact(Command, "date +%Z"),
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
    # caddyfile_auth_pass is the plaintext, which the apps with their own login use too
    auth_hash = caddy_password_hash(
        fact["caddyfile_auth_pass"],
        f"{fact['caddyfile_auth_user']}@{fact['server_domain']}",
    )
    return render(
        CADDYFILE_TEMPLATE,
        {**fact, "caddyfile_auth_hash": auth_hash, "application": application},
    )


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


def host_vars() -> dict:
    """What the deploy code and templates see: host data, the `host` facts, then the cue
    output on top"""
    fact, output = _facts()
    return {**fact, **output}
