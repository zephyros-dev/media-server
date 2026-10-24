import json

from pyinfra import host

from deploy import host as host_setup
from deploy.application import quadlet
from deploy.common.data import REPO
from deploy.common.facts import cue_facts

facts = cue_facts()

# `--data cue_fact_debug=true` dumps the cue output
if host.data.get("cue_fact_debug"):
    debug_dir = REPO / "deploy/cue/tmp"
    debug_dir.mkdir(exist_ok=True)
    (debug_dir / f"cue-{host.name}.json").write_text(
        json.dumps(facts, indent=2, sort_keys=True)
    )


def _selected_apps(application: dict) -> dict:
    """`--data apps=a,b` deploys only those apps (replaces ansible's `--tags`)"""
    apps = host.data.get("apps")
    if not apps:
        return application
    if isinstance(apps, str):
        apps = apps.split(",")
    keys = [app.strip().replace("-", "_") for app in apps]
    unknown = sorted(set(keys) - application.keys())
    if unknown:
        raise ValueError(f"Unknown apps: {', '.join(unknown)}")
    return {key: application[key] for key in keys}


# Like ansible's `--tags <app>`, selected apps skip the host setup.
# `--data host_only=true` runs the host setup alone
if not host.data.get("apps"):
    host_setup.deploy()
if not host.data.get("host_only"):
    for key, app in _selected_apps(facts["application"]).items():
        quadlet.deploy(key, app)
