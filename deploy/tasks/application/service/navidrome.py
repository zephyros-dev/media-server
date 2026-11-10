"""A dedicated user for musicgrabber's rescans and duplicate checks (admin, since navidrome
only lets admins trigger a scan), and the Mood Playlists plugin"""

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
MOOD_PLUGIN = "mood-playlists"
MOOD_PLUGIN_REPO = "RFLundgren/navidrome-mood-plugin"
MOOD_PLUGIN_ASSET = "mood-playlists.ndp"
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
    _install_plugin(MOOD_PLUGIN, MOOD_PLUGIN_REPO, MOOD_PLUGIN_ASSET)
    app.service()
    python.call(name=f"{app.name}: {USER} user", function=_user)
    python.call(
        name=f"{app.name}: {MOOD_PLUGIN} plugin", function=_mood_plugin, app=app
    )


def _install_plugin(plugin: str, repo: str, asset: str):
    """The release pinned in dependencies.yaml (kept at the latest by renovate), copied to
    the plugins folder: navidrome finds it there, by itself or on the rescan below"""
    tag = yaml.safe_load((REPO / "dependencies.yaml").read_text())[repo]
    version = tag.removeprefix("v")
    plugins = f"{host_vars()['global_volume_path']}/navidrome/data/plugins"
    ndp = f"{plugins}/{plugin}.ndp"
    url = f"https://github.com/{repo}/releases/download/{tag}/{asset}"
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

    files.directory(
        name=f"navidrome: {plugin} plugins folder", path=plugins, present=True
    )
    if installed != version:
        server.shell(
            name=f"navidrome: install {plugin} {version}",
            commands=[
                f"curl -fsSL -o {ndp}.download {url}",
                f"mv {ndp}.download {ndp}",
            ],
        )


def _plugin_info(plugin: str) -> dict:
    """`plugin info` once navidrome has picked the plugin up"""

    def installed() -> dict:
        _, output = run.run(f"{CLI} plugin list --format json --nobanner")
        if not any(p["id"] == plugin for p in json.loads(output.stdout)):
            # Not picked up (yet): the autoreload may be late, the first start has no
            # database to list from
            run.run(f"{CLI} plugin rescan --nobanner", check=False)
            raise FileNotFoundError(plugin)
        _, info = run.run(f"{CLI} plugin info {plugin} --format json --nobanner")
        return json.loads(info.stdout)

    return run.retry(installed, retries=60)


def _mood_plugin(app: App):
    """It talks to navidrome's API as the musicgrabber admin (global playlists and the
    scheduled tasks need an admin), and to the mood-analyzer app, whose address and music
    path are the plugin's defaults. It makes playlists for every user and reads every
    library, which navidrome won't enable it without"""
    info = _plugin_info(MOOD_PLUGIN)
    config = json.loads(info.get("config") or "{}")
    wanted = {
        "navidrome_user": host_vars()["navidrome_mood_user"],
        "navidrome_password": host_vars()["navidrome_mood_password"],
        # The plugin sends it with each request to the analyzer, which has no setting of its own
        "lastfm_api_key": host_vars()["navidrome_lastfm_api_key"],
        # Noon in navidrome's timezone (UTC+7, the server's), where the default is 02:00
        "analyze_schedule": "0 12 * * *",
        # Daily at 14 PM, where the default is Sundays at 03:00
        "playlist_refresh_schedule": "0 14 * * *",
    }
    flags = []
    if not info.get("allUsers"):
        flags.append("--all-users")
    if not info.get("allLibraries"):
        flags.append("--all-libraries")
    if any(config.get(key) != value for key, value in wanted.items()):
        # Only the managed keys, the rest of the settings are the UI's
        flags.append("--config-file -")
    if flags:
        run.run(
            f"podman exec -i navidrome-web /app/navidrome plugin edit {MOOD_PLUGIN}"
            f" {' '.join(flags)} --nobanner",
            stdin=json.dumps({**config, **wanted}),
            secret=True,
        )
    if not info["enabled"]:
        run.run(f"{CLI} plugin enable {MOOD_PLUGIN} --nobanner")
    if flags or not info["enabled"]:
        # The running server reads the plugin's config and schedules when it loads it: the
        # CLI only changes the stored settings, and a file touch doesn't reload it either
        run.systemctl("restart", app.name, app.become)


def _user():
    # The server creates the database schema on startup, so retry until it's there
    _, output = run.retry(
        lambda: run.run(f"{CLI} user list --format csv --nobanner"), retries=30
    )
    # csv columns: user id,username,name,email,admin,...
    users = {
        row[1]: row for line in output.stdout_lines if len(row := line.split(",")) > 4
    }

    password = host_vars()["navidrome_musicgrabber_password"]
    if USER not in users:
        _set_password("create", password, "--admin")
        return
    # For a user created before it was made admin
    if users[USER][4] == "false":
        run.run(f"{CLI} user edit --user {USER} --set-admin --nobanner")
    # The secret is the source of truth, but navidrome keeps no password to compare with:
    # log in with it, and set it when navidrome refuses
    if not _password_works(password):
        _set_password("edit", password, "--set-password")


def _set_password(command: str, password: str, flag: str):
    """`user create` and `user edit --set-password` only read the password from a terminal,
    for both prompts (new and confirm). It goes in on stdin, out of argv"""
    run.run(
        f"python3 -c {shlex.quote(EXPECT_PASSWORD)}"
        f" podman exec -it navidrome-web /app/navidrome user {command}"
        f" --{'username' if command == 'create' else 'user'} {USER} {flag} --nobanner",
        stdin=f"{password}\n",
    )


def _password_works(password: str) -> bool:
    """Log in with navidrome's own endpoint, which takes the password as it is: the Subsonic
    one wants md5(password + salt), a hash of the password it can't do without. The body goes
    in on stdin, out of argv. A refusal is a 401, any other failure isn't an answer"""
    ok, output = run.run(
        "podman exec -i navidrome-web wget -qO- --post-file=-"
        ' --header "Content-Type: application/json" http://localhost:4533/auth/login',
        stdin=json.dumps({"username": USER, "password": password}),
        check=False,
        secret=True,
    )
    if ok:
        return True
    if any("401" in line for line in output.stderr_lines):
        return False
    raise RuntimeError(f"could not check the {USER} login: {output.stderr_lines}")
