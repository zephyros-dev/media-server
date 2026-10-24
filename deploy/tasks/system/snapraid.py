"""snapraid, the snapper configs it snapshots with, and snapraid-btrfs-runner"""

import re
from io import StringIO

from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from deploy.tasks.common.data import REPO
from deploy.tasks.system import snapper
from deploy.tasks.system.common import template

SUBMODULES = REPO / "submodules"
RUNNER_PATH = "/opt/snapraid-btrfs-runner"
RUNNER_CONFIG = {
    ("snapraid-btrfs", "executable"): "/usr/local/bin/snapraid-btrfs",
    ("snapper", "executable"): "/usr/bin/snapper",
    ("snapraid", "executable"): "/usr/bin/snapraid",
    ("snapraid", "config"): "/etc/snapraid.conf",
    ("logging", "file"): "",
}


def deploy():
    files.put(
        name="Install snapraid-btrfs",
        src=str(SUBMODULES / "snapraid-btrfs/snapraid-btrfs"),
        dest="/usr/local/bin/snapraid-btrfs",
        mode="755",
        _sudo=True,
    )
    template("snapraid/snapraid.conf.j2", "/etc/snapraid.conf", mode="644", become=True)
    snapper.deploy()
    _runner()


def _ini_set(content: str, section: str, option: str, value: str) -> str:
    """Set `option = value` in `[section]`, like ansible's ini_file does to an option that
    exists already"""
    pattern = re.compile(
        rf"(^\[{re.escape(section)}\]\n(?:(?!\[).*\n)*?){re.escape(option)}[ \t]*=.*$",
        re.MULTILINE,
    )
    content, count = pattern.subn(rf"\g<1>{option} = {value}", content, count=1)
    if not count:
        raise ValueError(f"No option {option} in [{section}] of the runner config")
    return content


def _runner():
    files.directory(
        name="snapraid-btrfs-runner folder", path=RUNNER_PATH, mode="755", _sudo=True
    )
    runner = SUBMODULES / "snapraid-btrfs-runner"
    files.put(
        name="Install snapraid-btrfs-runner",
        src=str(runner / "snapraid-btrfs-runner.py"),
        dest=f"{RUNNER_PATH}/snapraid-btrfs-runner.py",
        mode="700",
        _sudo=True,
    )
    example = (runner / "snapraid-btrfs-runner.conf.example").read_text()
    files.put(
        name="snapraid-btrfs-runner default config",
        src=StringIO(example),
        dest=f"{RUNNER_PATH}/snapraid-btrfs-runner.conf.example",
        mode="600",
        _sudo=True,
    )
    # Ansible copied the example over the config when the example changed, then set these
    # options. Rendered whole here, so a hand edit of another option doesn't survive
    config = example
    for (section, option), value in RUNNER_CONFIG.items():
        config = _ini_set(config, section, option, value)
    files.put(
        name="snapraid-btrfs-runner config",
        src=StringIO(config),
        dest=f"{RUNNER_PATH}/snapraid-btrfs-runner.conf",
        mode="600",
        _sudo=True,
    )

    units = [
        template(
            f"snapraid/snapraid-runner.{unit}.j2",
            f"/etc/systemd/system/snapraid-runner.{unit}",
            mode="600",
            become=True,
            snapraid_runner_path=RUNNER_PATH,
        )
        for unit in ("service", "timer")
    ]
    systemd.daemon_reload(
        name="snapraid-runner: daemon-reload", _sudo=True, _if=any_changed(*units)
    )
    systemd.service(
        name="Enable snapraid-runner timer",
        service="snapraid-runner.timer",
        running=True,
        enabled=True,
        _sudo=True,
    )
