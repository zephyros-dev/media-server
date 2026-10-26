"""systemd ops pyinfra lacks: its systemd.service can't queue a job with --no-block"""

from pyinfra import host
from pyinfra.api import FactBase, operation


class ActiveStates(FactBase):
    """`{unit: ActiveState}` of the loaded service units, one lookup instead of a `show` per
    unit. A unit that isn't loaded isn't in it, which `show` reports as inactive"""

    def command(self, user_mode=False):
        user = " --user" if user_mode else ""
        return f"systemctl{user} list-units --type=service --all --plain --no-legend"

    def process(self, output):
        # UNIT LOAD ACTIVE SUB DESCRIPTION
        return {line.split()[0]: line.split()[2] for line in output if line.strip()}


# pyinfra doesn't cache facts, and every service would look the same list up again. All the
# operations are prepared before any runs, so it can't go stale during the deploy
_states: dict[tuple[str, bool, bool], dict[str, str]] = {}


def _active_states(user_mode: bool) -> dict[str, str]:
    sudo = bool(host.current_op_global_arguments.get("_sudo"))
    key = (host.name, user_mode, sudo)
    if key not in _states:
        _states[key] = host.get_fact(ActiveStates, user_mode=user_mode)
    return _states[key]


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
    active_state = _active_states(user_mode).get(unit, "inactive")
    running = active_state in ("active", "activating")
    if state == "started" and not running:
        yield f"{command} start {unit}"
    elif state == "stopped" and running:
        yield f"{command} stop {unit}"
