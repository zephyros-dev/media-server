"""Configure the library, the content server and its user without
going through the calibre GUI. The GUI keeps its prefs in memory and rewrites them on exit,
so every change is done with the service stopped, and only when needed"""

import json
import re
import shlex

from pyinfra.operations import python

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.facts import host_vars

PREFS = {
    # Despite the name this is JSON; without the flag a fresh GUI blocks on
    # the welcome wizard and never autolaunches the content server
    "dynamic.pickle.json": {"welcome_wizard_was_run": True},
    "global.py.json": {"library_path": "/books"},
    # Automatic adding (Add books > Control the adding of books) from the ingest
    # volume, which calibre-dl downloads into
    "gui.json": {
        "auto_add_path": "/config/ingest",
        "auto_add_check_for_duplicates": True,
    },
    "gui.py.json": {"autolaunch_server": True},
}
SERVER_CONFIG = {"auth": "True", "auth_mode": "basic", "port": "8081"}
USERDB = "/config/.config/calibre/server-users.sqlite"


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: unattended setup", function=_setup, app=app)


def _prefs(content: str | None) -> dict:
    return json.loads(content) if content and content.strip() else {}


def _server_config(content: str) -> str:
    """server-config.txt is "<option> <value>" per line; other options set from the GUI
    are kept, like ansible's lineinfile"""
    lines = content.splitlines()
    for key, value in SERVER_CONFIG.items():
        line = f"{key} {value}"
        matches = [
            i for i, current in enumerate(lines) if re.match(rf"{key}\s", current)
        ]
        if matches:
            lines[matches[-1]] = line
        else:
            lines.append(line)
    return "\n".join(lines) + "\n"


def _setup(app: App):
    v = host_vars()
    config_path = f"{v['global_volume_path']}/calibre/config/.config/calibre"
    books_path = f"{v['global_media']}/Storage/Books"
    server_config_path = f"{config_path}/server-config.txt"
    # The image the pod runs: the pinned ref from its Containerfile, or the locally built
    # one if it ever gets real build steps
    image = v["container_images"].get("calibre", "localhost/calibre:latest")
    # One-shot container with the same mounts and uid as the service, for use while it
    # is stopped
    calibre_run = (
        "podman run --rm --userns keep-id:uid=911,gid=911 --user 911:911 --env HOME=/tmp"
        f" --volume {shlex.quote(v['global_volume_path'])}/calibre/config:/config:z"
        f" --volume {shlex.quote(books_path)}:/books"
    )
    user = v["calibre_server_user"]

    # The image is built and started asynchronously; the image's init script writes
    # server-config.txt once the container is up
    def initialized():
        if not run.exists(server_config_path):
            raise FileNotFoundError(server_config_path)

    run.retry(initialized, retries=120)

    def stale(name: str, current: dict) -> bool:
        return {**current, **PREFS[name]} != current

    stale_prefs = [
        name for name in PREFS if stale(name, _prefs(run.read(f"{config_path}/{name}")))
    ]
    server_config = run.read(server_config_path) or ""
    server_config_stale = _server_config(server_config) != server_config
    has_library = run.exists(f"{books_path}/metadata.db")

    # Retried: after a restart server-config.txt already exists, so the wait above passes
    # while the container may still be coming back up. As abc: on a fresh host this creates
    # the user db, which must not end up owned by root
    _, users = run.retry(
        lambda: run.run(
            "podman exec --user abc calibre-web calibre-server"
            f" --userdb {USERDB} --manage-users -- list"
        ),
        retries=60,
    )
    has_user = user in users.stdout_lines

    if not (stale_prefs or server_config_stale) and has_library and has_user:
        return

    # Like ansible's block/always: started again even if the stop itself fails
    try:
        run.systemctl("stop", app.name, app.become)
        # Re-read now that the GUI has flushed its prefs on exit
        for name in stale_prefs:
            path = f"{config_path}/{name}"
            prefs = {**_prefs(run.read(path)), **PREFS[name]}
            # Like ansible's to_nice_json(indent=2)
            run.write(path, json.dumps(prefs, indent=2, sort_keys=True), mode="644")
        server_config = run.read(server_config_path) or ""
        if _server_config(server_config) != server_config:
            run.write(server_config_path, _server_config(server_config))

        # calibredb creates an empty library when the folder has none
        if not has_library:
            run.run(
                f"{calibre_run} --entrypoint calibredb {image} --with-library /books list"
            )
        if not has_user:
            run.run(
                f"{calibre_run} --entrypoint calibre-server {image}"
                f" --userdb {USERDB} --manage-users --"
                f" add {shlex.quote(user)} {shlex.quote(v['calibre_server_password'])}",
                secret=True,
            )
    finally:
        run.systemctl("start", app.name, app.become)
