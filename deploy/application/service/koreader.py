"""Install the syncery.koplugin version pinned in
dependencies.yaml"""

import re

import yaml
from pyinfra import host
from pyinfra.facts.files import FindInFile
from pyinfra.operations import files, server

from deploy.application.quadlet import App
from deploy.common.data import REPO
from deploy.common.facts import host_vars
from deploy.ops import systemd as systemd_ops

RELEASES = "https://github.com/d0nizam/syncery.koplugin/releases/download"


def deploy(app: App):
    plugins = (
        f"{host_vars()['global_volume_path']}/koreader/data/.config/koreader/plugins"
    )
    plugin = f"{plugins}/syncery.koplugin"
    # Kept at the latest release by renovate, so compare against it exactly
    dependencies = yaml.safe_load((REPO / "dependencies.yaml").read_text())
    version = dependencies["d0nizam/syncery.koplugin"].removeprefix("v")

    files.directory(
        name=f"{app.name}: plugins folder", path=plugins, mode="755", present=True
    )
    # _meta.lua has `version = "x.y.z"`
    meta = (
        host.get_fact(FindInFile, path=f"{plugin}/_meta.lua", pattern="version") or []
    )
    installed = next(
        (m[1] for line in meta if (m := re.search(r'version\s*=\s*"([^"]+)"', line))),
        "",
    )

    update = None
    if installed != version:
        # Replace rather than extract over it, so files dropped upstream don't linger
        files.directory(
            name=f"{app.name}: remove syncery.koplugin {installed}",
            path=plugin,
            present=False,
        )
        archive = "/tmp/syncery.koplugin.zip"
        update = server.shell(
            name=f"{app.name}: install syncery.koplugin {version}",
            commands=[
                f"curl -fsSL -o {archive} {RELEASES}/v{version}/syncery.koplugin.zip",
                f"python3 -m zipfile -e {archive} {plugins}",
                f"rm {archive}",
            ],
        )

    app.service()

    # koreader only loads plugins at startup
    if update:
        systemd_ops.service(
            name=f"{app.name}: restart to load syncery.koplugin {version}",
            service=app.name,
            state="restarted",
            user_mode=not app.become,
            _sudo=app.become,
        )
