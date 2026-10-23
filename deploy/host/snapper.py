"""Snapper configs for the btrfs data disks and /home (cue's `snapper_configs`), which
snapraid-btrfs snapshots before each sync"""

from pyinfra import host
from pyinfra.facts.files import Directory, File
from pyinfra.operations import files, server, systemd

from deploy.common.facts import host_vars
from deploy.host.common import template

CONFIG_DIR = "/etc/snapper/configs"
# Enabled, or disabled, but not started or stopped
TIMERS = {
    "snapper-timeline.timer": True,
    "snapper-cleanup.timer": True,
    "snapper-boot.timer": False,
}


def deploy():
    configs = host_vars()["snapper_configs"]
    # A subvolume with snapshots from before a reinstall: register its config again, so
    # `create-config` isn't run on it (which fails on an existing .snapshots)
    restored = [
        config
        for config in configs
        if host.get_fact(Directory, path=f"{config['path']}/.snapshots", _sudo=True)
    ]
    names = " ".join(config["name"] for config in restored)
    files.line(
        name="Snapper configs with snapshots",
        path="/etc/sysconfig/snapper",
        line="^SNAPPER_CONFIGS=.*$",
        replace=f'SNAPPER_CONFIGS="{names}"',
        _sudo=True,
    )
    files.directory(
        name="Snapper config folder", path=CONFIG_DIR, mode="755", _sudo=True
    )

    for config in configs:
        name, path = config["name"], config["path"]
        if config in restored:
            # A valid config for snapper to read until the template below replaces it
            # https://github.com/openSUSE/snapper/issues/408#issuecomment-554719988
            if not host.get_fact(File, path=f"{CONFIG_DIR}/{name}", _sudo=True):
                server.shell(
                    name=f"Snapper placeholder config {name}",
                    commands=[
                        f"printf 'SUBVOLUME=\"%s\"\\n' '{path}' > {CONFIG_DIR}/{name}",
                        f"chmod 644 {CONFIG_DIR}/{name}",
                    ],
                    _sudo=True,
                )
        else:
            # Also creates the .snapshots subvolume, so this runs once
            server.shell(
                name=f"Create snapper config {name}",
                commands=[f"snapper --config '{name}' create-config '{path}'"],
                _sudo=True,
            )
        template(
            "snapper/config.j2",
            f"{CONFIG_DIR}/{name}",
            mode="644",
            become=True,
            cfg=config["vars"],
            path=path,
        )

    for timer, enabled in TIMERS.items():
        systemd.service(
            name=f"{'Enable' if enabled else 'Disable'} {timer}",
            service=timer,
            running=None,
            enabled=enabled,
            _sudo=True,
        )
