"""rpm-ostree packages, podman config, power profile, automatic updates and cockpit"""

from pyinfra import host
from pyinfra.facts.files import File
from pyinfra.facts.server import Command
from pyinfra.operations import files, selinux, server, systemd

from deploy.tasks.system import rpm_ostree
from deploy.tasks.system.common import sysctl, template, user_dir

PACKAGES = [
    # Terminal tools
    "dua-cli",
    "fd-find",
    "fish",
    "powertop",
    # Server software
    "power-profiles-daemon",
    "restic",
    "snapper",
    "unzip",
]
CONTAINERS_CONF = "containers.conf.d/containers.conf"


def deploy():
    selinux.boolean(
        name="Allow virt to use fuse.mergerfs",
        bool_name="virt_use_fusefs",
        value=selinux.Boolean.ON,
        persistent=True,
        _sudo=True,
    )
    # The os-prober takes a long time since we have large disks. Only if it's there:
    # ansible's file state=file didn't create it
    os_prober = "/etc/grub.d/30_os-prober"
    if host.get_fact(File, path=os_prober):
        files.file(name="Disable os-prober", path=os_prober, mode="644", _sudo=True)

    packages = rpm_ostree.packages(
        name="Layer packages with rpm-ostree", packages=PACKAGES, _sudo=True
    )
    server.reboot(
        name="Reboot to apply rpm-ostree packages",
        reboot_timeout=600,
        _sudo=True,
        _if=packages.did_change,
    )

    _podman()

    systemd.service(
        name="Enable power-profiles-daemon",
        service="power-profiles-daemon.service",
        running=True,
        enabled=True,
        _sudo=True,
    )
    if host.get_fact(Command, "powerprofilesctl get || true") != "power-saver":
        server.shell(
            name="Enable low power mode",
            commands=["powerprofilesctl set power-saver"],
            # polkit only lets an ssh session switch profiles as root
            _sudo=True,
        )
    systemd.service(
        name="Enable automatic updates",
        service="rpm-ostreed-automatic.timer",
        running=True,
        enabled=True,
        _sudo=True,
    )
    systemd.service(
        name="Enable cockpit",
        service="cockpit.service",
        running=True,
        enabled=True,
        _sudo=True,
    )


def _podman():
    sysctl(
        "Allow rootless podman to bind ports from 80",
        "net.ipv4.ip_unprivileged_port_start",
        80,
    )
    files.directory(
        name="Podman config folder, root",
        path="/etc/containers/containers.conf.d",
        mode="755",
        _sudo=True,
    )
    template(
        "podman/containers.conf.j2",
        f"/etc/containers/{CONTAINERS_CONF}",
        mode="644",
        become=True,
    )

    systemd.service(
        name="Enable podman socket, rootless",
        service="podman.socket",
        running=True,
        enabled=True,
        user_mode=True,
    )
    files.directory(
        name="Podman config folder, rootless",
        path=f"{user_dir()}/.config/containers/containers.conf.d",
        mode="755",
    )
    template(
        "podman/containers.conf.j2",
        f"{user_dir()}/.config/containers/{CONTAINERS_CONF}",
        mode="644",
    )
