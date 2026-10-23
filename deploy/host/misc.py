"""SELinux, sysctl, and the user's libvirt group"""

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import files, server

from deploy.common.facts import host_vars
from deploy.host.common import sysctl

SYSCTL = {
    # Buffer size for HTTP/3 performance in caddy
    # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
    "net.core.rmem_max": 7500000,
    "net.core.wmem_max": 7500000,
    # inotify watches for Jellyfin
    # https://jellyfin.org/docs/general/administration/troubleshooting.html#real-time-monitoring
    "fs.inotify.max_user_instances": 512,
    "fs.inotify.max_user_watches": 524288,
}


def deploy():
    for key, value in {"SELINUX": "enforcing", "SELINUXTYPE": "targeted"}.items():
        files.line(
            name=f"SELinux config {key}",
            path="/etc/selinux/config",
            line=f"^{key}=.*$",
            replace=f"{key}={value}",
            _sudo=True,
        )
    # Only from permissive: a disabled SELinux needs the reboot (ansible only warned)
    if host.get_fact(Command, "getenforce") == "Permissive":
        server.shell(name="Enforce SELinux", commands=["setenforce 1"], _sudo=True)

    for key, value in SYSCTL.items():
        sysctl(f"sysctl {key}", key, value)

    server.user(
        name="Add the user to the libvirt group",
        user=host_vars()["host"]["user"],
        groups=["libvirt"],
        append=True,
        # Like ansible's user module, which never touched the home directory
        ensure_home=False,
        _sudo=True,
    )
