"""The `postgres_action` steps of a postgres
major upgrade (see the README): export, import with the new image, then clean the backup"""

import json
import os
import shlex

from pyinfra.operations import python

from deploy.application import run
from deploy.application.quadlet import App

# The data mount in the postgres container (/var/lib/postgresql/data before postgres 18)
DATA_MOUNT = "/var/lib/postgresql"


def deploy(app: App, action: str):
    python.call(
        name=f"{app.name}: postgres {action}",
        function=_action,
        app=app,
        action=action,
    )


def _action(app: App, action: str):
    container = f"{app.name}-postgres"

    def inspect() -> dict:
        _, output = run.run(f"podman container inspect {container}", sudo=app.become)
        return json.loads(output.stdout)[0]

    # Retried: the pod may still be starting
    info = run.retry(inspect, retries=10)
    data_path = next(
        m["Source"] for m in info["Mounts"] if m["Destination"] == DATA_MOUNT
    )
    user = next(
        e.removeprefix("POSTGRES_USER=")
        for e in info["Config"]["Env"]
        if e.startswith("POSTGRES_USER=")
    )
    backup_path = f"{os.path.dirname(data_path)}/postgres_backup"
    data, backup = shlex.quote(data_path), shlex.quote(backup_path)
    # The data is owned by the container's users: the file steps run in podman's user
    # namespace, unless the app runs as root
    as_owner = "" if app.become else "podman unshare "

    def shell(command: str):
        return run.run(command, sudo=app.become)

    if action != "clean":
        run.systemctl("stop", app.name, app.become)

    if action == "export":
        _, output = shell("date +%Y%m%dT%H%M%S")
        snapshot = shlex.quote(f"{backup_path}/{output.stdout.strip()}")
        shell(f"mkdir -p -m 700 {backup} {snapshot}")
        shell(f"{as_owner}cp -a {data} {snapshot}/")
        run.systemctl("start", app.name, app.become)
        run.retry(
            lambda: shell(
                f"podman exec {container} pg_dumpall -U {shlex.quote(user)}"
                f" > {backup}/dump.sql"
            ),
            retries=10,
        )
        # Left stopped: the next step is the import with the new postgres image
        run.systemctl("stop", app.name, app.become)
    elif action == "import":
        shell(f"{as_owner}rm -rf {data} && mkdir -m 700 {data}")
        run.systemctl("start", app.name, app.become)
        run.retry(
            lambda: shell(
                f"podman exec -i {container} psql -U {shlex.quote(user)}"
                f" < {backup}/dump.sql"
            ),
            retries=10,
        )
    elif action == "clean":
        shell(f"{as_owner}rm -rf {backup}")
