"""A dedicated user for musicgrabber's rescans and duplicate checks (admin, since navidrome
only lets admins trigger a scan), and the NaviBeat Mixes plugin"""

import json
import shlex

import yaml
from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import files, python, server

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.data import REPO
from deploy.tasks.common.facts import host_vars

CLI = "podman exec navidrome-web /app/navidrome"
USER = "musicgrabber"
PLUGIN = "navibeat-mixes"
PLUGIN_REPO = "nenadjokic/navibeat-mixes"
# The build for navidrome 0.64 and up, the release has another one for 0.63
PLUGIN_ASSET = "navibeat-mixes-navidrome-0.64.ndp"
# Runs `argv` in a terminal and answers each password prompt with the first stdin line,
# like ansible's expect module (the host has python, not `script` or `expect`)
EXPECT_PASSWORD = """
import os, pty, sys
password = sys.stdin.readline().encode()
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
output = b""
while True:
    try:
        chunk = os.read(fd, 1024)
    except OSError:
        break
    if not chunk:
        break
    output += chunk
    if b"password" in output.lower().rsplit(b"\\n", 1)[-1]:
        os.write(fd, password)
        output += b"\\n"
sys.exit(os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1]))
"""


def deploy(app: App):
    _install_plugin()
    app.service()
    python.call(name=f"{app.name}: {USER} user", function=_user)
    python.call(name=f"{app.name}: {PLUGIN} plugin", function=_plugin)


def _install_plugin():
    """The release pinned in dependencies.yaml (kept at the latest by renovate), copied to
    the plugins folder: navidrome finds it there, by itself or on the rescan below"""
    tag = yaml.safe_load((REPO / "dependencies.yaml").read_text())[PLUGIN_REPO]
    version = tag.removeprefix("v")
    plugins = f"{host_vars()['global_volume_path']}/navidrome/data/plugins"
    ndp = f"{plugins}/{PLUGIN}.ndp"
    url = f"https://github.com/{PLUGIN_REPO}/releases/download/{tag}/{PLUGIN_ASSET}"
    manifest_version = (
        "import json, sys, zipfile;"
        " print(json.load(zipfile.ZipFile(sys.argv[1]).open('manifest.json'))['version'])"
    )
    # None without a plugin file: no output
    installed = (
        host.get_fact(
            Command,
            f"python3 -c {shlex.quote(manifest_version)} {ndp} 2>/dev/null || true",
        )
        or ""
    ).strip()

    files.directory(name="navidrome: plugins folder", path=plugins, present=True)
    if installed != version:
        server.shell(
            name=f"navidrome: install {PLUGIN} {version}",
            commands=[
                f"curl -fsSL -o {ndp}.download {url}",
                f"mv {ndp}.download {ndp}",
            ],
        )


def _plugin():
    user = host_vars()["navibeat_user"]

    def installed() -> dict:
        _, output = run.run(f"{CLI} plugin list --format json --nobanner")
        if not any(p["id"] == PLUGIN for p in json.loads(output.stdout)):
            # Not picked up (yet): the autoreload may be late, the first start has no
            # database to list from
            run.run(f"{CLI} plugin rescan --nobanner", check=False)
            raise FileNotFoundError(PLUGIN)
        _, info = run.run(f"{CLI} plugin info {PLUGIN} --format json --nobanner")
        return json.loads(info.stdout)

    info = run.retry(installed, retries=60)

    # It builds mixes per user, and won't enable without users to act as. Only this one.
    # The grant takes the id of the user, whatever `plugin edit --help` says about
    # usernames: with a username the plugin is told there are no users
    _, output = run.run(f"{CLI} user list --format csv --nobanner")
    # csv columns: user id,username,name,email,admin,...
    user_id = next(
        (
            row[0]
            for line in output.stdout_lines
            if (row := line.split(","))[1:2] == [user]
        ),
        None,
    )
    if user_id is None:
        raise RuntimeError(f"navidrome has no user {user}")

    config = json.loads(info.get("config") or "{}")
    # The setting is the usernames
    wanted = {"onlyForUsers": user}
    flags = []
    if info.get("allUsers") or json.loads(info.get("users") or "[]") != [user_id]:
        flags.append(f"--users {shlex.quote(user_id)}")
    if any(config.get(key) != value for key, value in wanted.items()):
        # Only the managed keys, the rest of the settings are the UI's
        flags.append("--config-file -")
    if flags:
        run.run(
            f"podman exec -i navidrome-web /app/navidrome plugin edit {PLUGIN}"
            f" {' '.join(flags)} --nobanner",
            stdin=json.dumps({**config, **wanted}),
        )
    if not info["enabled"]:
        run.run(f"{CLI} plugin enable {PLUGIN} --nobanner")


def _user():
    # The server creates the database schema on startup, so retry until it's there
    _, output = run.retry(
        lambda: run.run(f"{CLI} user list --format csv --nobanner"), retries=30
    )
    # csv columns: user id,username,name,email,admin,...
    users = {
        row[1]: row for line in output.stdout_lines if len(row := line.split(",")) > 4
    }

    if USER not in users:
        # `user create` only reads the password from a terminal, for both prompts (new and
        # confirm). The password goes in on stdin, out of argv
        password = host_vars()["navidrome_musicgrabber_password"]
        run.run(
            f"python3 -c {shlex.quote(EXPECT_PASSWORD)}"
            " podman exec -it navidrome-web /app/navidrome user create"
            f" --username {USER} --admin --nobanner",
            stdin=f"{password}\n",
        )
    # For a user created before it was made admin
    elif users[USER][4] == "false":
        run.run(f"{CLI} user edit --user {USER} --set-admin --nobanner")
