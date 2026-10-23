"""systemd ops pyinfra lacks: its systemd.service can't queue a job with --no-block"""

from pyinfra import host
from pyinfra.api import operation
from pyinfra.facts.server import Command


@operation()
def service(service: str, state: str, user_mode=False, no_block=False):
    """Start, restart or stop `<service>.service`, or the unit `service` if it has a suffix

    + state: started (only if not running), restarted (always) or stopped (only if running)
    + no_block: queue the job and return, instead of waiting for it, e.g. on an image build
    """
    unit = service if "." in service else f"{service}.service"
    command = " ".join(
        [
            "systemctl",
            *(["--user"] if user_mode else []),
            *(["--no-block"] if no_block else []),
        ]
    )
    if state == "restarted":
        yield f"{command} restart {unit}"
        return

    # Like ansible's systemd module: a unit still starting (e.g. pulling its image) or
    # between Restart= attempts counts as running. pyinfra's SystemdStatus only looks at
    # the SubState, which calls those not running
    active_state = host.get_fact(
        Command,
        f"systemctl {'--user ' if user_mode else ''}show --property=ActiveState"
        f" --value {unit}",
    )
    running = active_state in ("active", "activating")
    if state == "started" and not running:
        yield f"{command} start {unit}"
    elif state == "stopped" and running:
        yield f"{command} stop {unit}"
