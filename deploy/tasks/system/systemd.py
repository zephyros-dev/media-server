"""A templated
service, run on a schedule by a timer or else enabled and started"""

from pyinfra import host
from pyinfra.facts.files import File
from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from deploy.tasks.system import systemctl as systemd_ops
from deploy.tasks.system.common import template, user_dir


def _unit_dir(become: bool) -> str:
    return "/etc/systemd/system" if become else f"{user_dir()}/.config/systemd/user"


def unit(name: str, become=False, schedule="", state="started"):
    """`name`.service from templates/systemd/<name>.service.j2

    + schedule: OnCalendar= of a `name`.timer that runs it, instead of starting it
    + state: started, stopped (only the timer) or absent
    """
    path = f"{_unit_dir(become)}/{name}.service"
    if state == "absent":
        _remove(name, path, become)
        if schedule:
            timer(name, become, schedule, state)
        return

    service = template(
        f"systemd/{name}.service.j2",
        path,
        mode="600",
        become=become,
        systemd_become=become,
    )
    if schedule:
        timer(name, become, schedule, state, changed=[service])
        return
    systemd.daemon_reload(
        name=f"{name}: daemon-reload",
        user_mode=not become,
        _sudo=become,
        _if=service.did_change,
    )
    # Like ansible: a changed service isn't restarted, it runs with the new unit next time
    systemd.service(
        name=f"{name}: enabled",
        service=f"{name}.service",
        running=True,
        enabled=True,
        user_mode=not become,
        _sudo=become,
    )


def timer(name: str, become: bool, schedule: str, state="started", changed=()):
    """`name`.timer, restarted when it changed

    + changed: ops of the timer's units, they need a daemon-reload too
    """
    path = f"{_unit_dir(become)}/{name}.timer"
    if state == "absent":
        _remove(f"{name}.timer", path, become)
        return

    timer_file = template(
        "systemd/timer.j2",
        path,
        mode="600",
        become=become,
        systemd_timer_name=name,
        systemd_timer_schedule=schedule,
    )
    systemd.daemon_reload(
        name=f"{name}.timer: daemon-reload",
        user_mode=not become,
        _sudo=become,
        _if=any_changed(timer_file, *changed),
    )
    systemd.service(
        name=f"{name}.timer: enabled",
        service=f"{name}.timer",
        running=state == "started",
        enabled=True,
        user_mode=not become,
        _sudo=become,
    )
    if state == "started":
        systemd_ops.service(
            name=f"{name}.timer: restarted",
            service=f"{name}.timer",
            state="restarted",
            user_mode=not become,
            _sudo=become,
            _if=timer_file.did_change,
        )


def _remove(unit_name: str, path: str, become: bool):
    if not host.get_fact(File, path=path, _sudo=become):
        return
    if "." not in unit_name:
        unit_name = f"{unit_name}.service"
    systemd.service(
        name=f"{unit_name}: stopped",
        service=unit_name,
        running=False,
        enabled=False,
        user_mode=not become,
        _sudo=become,
    )
    files.file(name=f"{unit_name}: removed", path=path, present=False, _sudo=become)
    systemd.daemon_reload(
        name=f"{unit_name}: daemon-reload", user_mode=not become, _sudo=become
    )
