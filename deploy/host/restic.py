"""restic backups: the env file, repo init or unlock, the exclude file, services and timers"""

from pyinfra import host
from pyinfra.api import FactBase
from pyinfra.operations import files, server

from deploy.common.facts import ansible_vars
from deploy.host import systemd
from deploy.host.common import template

UNITS = [
    "restic-backup",
    "restic-prune",
    # Only run by hand, to unlock the repo
    "restic-unlock",
]
TIMERS = {
    "restic-backup": "23:00:00",
    "restic-prune": "Wed 8:00:00",
}
# `restic cat config` errors that ansible answers with an init or an unlock
REPO_MISSING = ("bucket not found", "Is there a repository at the following location")
REPO_LOCKED = "unable to create lock in backend"


def _load_env(env_path: str) -> str:
    """Export each KEY=value line of the env file as is, like ansible's `environment:` and
    systemd's EnvironmentFile. Sourcing it would let the shell expand `$`, quotes, ..."""
    return (
        'while IFS= read -r line || [ -n "$line" ]; do'
        f' case $line in *=*) export "$line" ;; esac; done < {env_path}'
    )


class RepoStatus(FactBase):
    """stderr of `restic cat config` with the env file, `ok` if the repo is usable,
    `unknown` if restic or the env file isn't there yet"""

    def command(self, env_path: str):
        return (
            f"test -r {env_path} && command -v restic > /dev/null || {{ echo unknown; exit 0; }}; "
            f"out=$({_load_env(env_path)}; restic cat config 2>&1 > /dev/null) "
            '&& echo ok || echo "$out"'
        )

    def process(self, output):
        return "\n".join(output)


def deploy():
    v = ansible_vars()
    env_path = v["restic_env_path"]

    files.directory(
        name="restic config folder",
        path=env_path.rsplit("/", 1)[0],
        mode="755",
        _sudo=True,
    )
    files.file(name="restic env file", path=env_path, mode="600", _sudo=True)
    # Line by line like ansible's ini_file, which leaves the rest of the file alone
    for key, value in v["restic_env"].items():
        files.line(
            name=f"restic env {key}",
            path=env_path,
            line=f"^{key}=.*$",
            replace=f"{key}={value}",
            _sudo=True,
        )

    _repo(env_path)

    template("restic/exclude.j2", v["restic_exclude_file"], mode="644", become=True)
    services = [
        template(
            f"restic/{unit}.service.j2",
            f"/etc/systemd/system/{unit}.service",
            mode="644",
            become=True,
        )
        for unit in UNITS
    ]
    for unit, schedule in TIMERS.items():
        systemd.timer(unit, become=True, schedule=schedule, changed=services)


def _repo(env_path: str):
    """Init the repo if it doesn't exist, unlock it if it's locked"""
    status = host.get_fact(RepoStatus, env_path=env_path, _sudo=True)
    if status == "ok":
        return
    script = (
        f"{_load_env(env_path)}; out=$(restic cat config 2>&1 > /dev/null) && exit 0; "
    )
    if status == "unknown":
        # Facts run before the env file and the restic package are set up, so decide later
        missing = " || ".join(
            f'echo "$out" | grep -q "{error}"' for error in REPO_MISSING
        )
        script += (
            f"if {missing}; then restic init; "
            f'elif echo "$out" | grep -q "{REPO_LOCKED}"; then restic unlock; fi'
        )
    elif any(error in status for error in REPO_MISSING):
        script += "restic init"
    elif REPO_LOCKED in status:
        script += "restic unlock"
    else:
        # Same as ansible, other errors (e.g. no network) are left alone
        return
    server.shell(name="restic repo init or unlock", commands=[script], _sudo=True)
