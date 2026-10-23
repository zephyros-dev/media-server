"""Cockpit web console: its systemd override and config"""

from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from deploy.host.common import template
from deploy.ops import systemd as systemd_ops


def deploy():
    files.directory(
        name="cockpit service override folder",
        path="/etc/systemd/system/cockpit.service.d",
        mode="755",
        user="root",
        group="root",
        _sudo=True,
    )
    override = template(
        "cockpit/override.conf.j2",
        "/etc/systemd/system/cockpit.service.d/override.conf",
        mode="644",
        become=True,
    )
    config = template(
        "cockpit/cockpit.conf.j2", "/etc/cockpit/cockpit.conf", mode="644", become=True
    )

    # Ansible's handler
    changed = any_changed(override, config)
    systemd.daemon_reload(name="cockpit: daemon-reload", _sudo=True, _if=changed)
    systemd_ops.service(
        name="Restart cockpit",
        service="cockpit",
        state="restarted",
        _sudo=True,
        _if=changed,
    )
