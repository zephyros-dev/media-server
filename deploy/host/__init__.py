"""Host setup, before the apps are deployed"""

from pyinfra import host
from pyinfra.facts.files import File
from pyinfra.operations import server

from deploy.common.facts import host_vars
from deploy.host import (
    cockpit,
    mergerfs_directory,
    misc,
    mount,
    network,
    packages,
    partition,
    restic,
    snapraid,
    systemd,
)

# name, run as root, OnCalendar= schedule
UNITS = [
    ("shutdown", True, "00:00:00"),
    ("podman-prune", False, "Sat 19:00:00"),
    # Same unit for the rootful store (/var/lib/containers) of become apps
    ("podman-prune", True, "Sat 19:30:00"),
    ("add-executable", False, "20:00:00"),
    ("mergerfs-directory", False, "*:00:00"),
    # Nextcloud's background jobs are in cron mode, which needs this to run them
    ("nextcloud-cron", False, "*:0/5"),
]


def deploy():
    # A fresh staging VM gets blank disks. The server's disks are
    # partitioned by hand with deploy/partition.py
    if host_vars()["host"]["hostname"] == "staging":
        partition.deploy()
    network.deploy()
    packages.deploy()
    restic.deploy()
    mount.deploy()

    user = host_vars()["host"]["user"]
    if not host.get_fact(File, path=f"/var/lib/systemd/linger/{user}"):
        server.shell(
            name="Enable lingering", commands=[f"loginctl enable-linger {user}"]
        )
    for name, become, schedule in UNITS:
        systemd.unit(name, become=become, schedule=schedule)

    mergerfs_directory.deploy()
    snapraid.deploy()
    misc.deploy()
    cockpit.deploy()
