"""Helpers shared by the host setup modules"""

from io import StringIO

from pyinfra.operations import files, server

from deploy.tasks.common.facts import host_vars
from deploy.tasks.common.templates import render


def user_dir() -> str:
    return host_vars()["host"]["home"]


def sysctl(name: str, key: str, value: int):
    """Like ansible's sysctl: set it now and persist it in /etc/sysctl.conf. pyinfra's own
    persist only matches a line that already has this value, so a changed value was
    appended next to the old line instead of replacing it"""
    server.sysctl(name=name, key=key, value=value, _sudo=True)
    files.line(
        name=f"{name}: persist",
        path="/etc/sysctl.conf",
        line=f"^{key}[[:space:]]*=.*$",
        replace=f"{key} = {value}",
        _sudo=True,
    )


def template(
    name: str,
    dest: str,
    mode: str,
    become=False,
    **context,
):
    """Like ansible's template module: `deploy/tasks/system/templates/<name>` rendered with the
    host's vars, plus `context`"""
    return files.put(
        name=f"Template {dest}",
        src=StringIO(render(name, {**host_vars(), **context}, package="tasks/system")),
        dest=dest,
        mode=mode,
        _sudo=become,
    )
