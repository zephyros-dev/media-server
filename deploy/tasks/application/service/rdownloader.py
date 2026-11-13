"""The first setup of rDownloader, which its wizard asks for: the administrator password, the
external URL (until it is set the app answers to IP addresses only, which the proxy's name is
not), a storage root and a category. Through the API the web UI uses, and only while the
wizard isn't completed: what is changed in the UI afterwards is left alone"""

import json
import shlex

from pyinfra.operations import python

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.facts import host_vars

PORT = 8710
# The mounted fallback storage root of the app, see the volumes in cue
STORAGE_PATH = "/downloads"
# Runs in the container, which has python. The settings
# are what the UI keeps, read back and sent whole with the one field changed. Nothing is
# done once the wizard is completed, or when the password has been changed in the UI
SETUP = f"""
import json, sys, urllib.error, urllib.request

config = json.load(sys.stdin)
base = "http://localhost:{PORT}/api/v1"
# The session cookie is sent by hand: with an https external URL it is marked Secure, and a
# cookie jar doesn't send that over this plain http
session = {{}}


def call(method, path, body=None, refused=False):
    request = urllib.request.Request(
        base + path,
        data=None if body is None else json.dumps(body).encode(),
        headers={{"Content-Type": "application/json", **session}},
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if cookie := response.headers.get("Set-Cookie"):
                session["Cookie"] = cookie.split(";")[0]
            return json.load(response)
    except urllib.error.HTTPError as error:
        if refused and error.code in (401, 403):
            return None
        sys.exit(f"{{method}} {{path}}: {{error.code}} {{error.read().decode()[:300]}}")


if call("GET", "/auth/status")["setup_required"]:
    call("POST", "/auth/setup", {{"password": config["password"]}})
# A password that isn't ours was set in the UI: the app is configured, leave it alone
if call("POST", "/auth/login", {{"password": config["password"]}}, refused=True) is None:
    sys.exit(0)
if call("GET", "/setup/status")["wizard_completed"]:
    sys.exit(0)

settings = call("GET", "/settings")
settings["external_url"] = config["external_url"]
call("PUT", "/settings", settings)

roots = {{root["path"]: root for root in call("GET", "/storage-roots")}}
root = roots.get(config["storage_path"]) or call(
    "POST",
    "/storage-roots",
    {{"name": "downloads", "path": config["storage_path"], "is_default": True}},
)
if not call("GET", "/categories"):
    call(
        "POST",
        "/categories",
        {{
            "name": "default",
            "color": "#4f46e5",
            "storage_root_id": root["id"],
            "relative_path": "",
            "is_default": True,
            "selectable": True,
        }},
    )
call("POST", "/setup/complete")
"""


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: first setup", function=_setup, app=app)


def _setup(app: App):
    v = host_vars()
    config = {
        "password": v["rdownloader_password"],
        "external_url": f"https://{app.name}.{v['server_domain']}",
        "storage_path": STORAGE_PATH,
    }
    # The first start installs plugins and loads the resolvers before it listens, about a
    # minute
    run.retry(
        lambda: run.run(
            f"podman exec -i {app.name}-web python3 -c {shlex.quote(SETUP)}",
            stdin=json.dumps(config),
            secret=True,
            sudo=app.become,
        ),
        retries=60,
    )
