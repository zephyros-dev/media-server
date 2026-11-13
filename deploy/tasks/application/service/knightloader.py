"""The instance password, which KnightLoader has no setting for: it is set through the API
the web UI uses. Only the first one: with a password set the API wants the current one, and
what is changed in the UI is left alone. Without a password it answers on IP addresses and
local names only, so this also is what lets it open on its domain"""

import shlex

from pyinfra.operations import python

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.facts import host_vars

PORT = 8749
# Runs in the container, which has python but no curl. The password comes in on stdin, out of
# argv. The local name has no dot, which the app answers on before it has a password
SET_PASSWORD = f"""
import json, sys, urllib.request
base = "http://localhost:{PORT}"
password = sys.stdin.readline().rstrip("\\n")
with urllib.request.urlopen(base + "/api/auth", timeout=10) as response:
    if json.load(response)["enabled"]:
        sys.exit(0)
request = urllib.request.Request(
    base + "/api/auth/password",
    data=json.dumps({{"current": "", "new": password}}).encode(),
    headers={{"Content-Type": "application/json"}},
    method="PUT",
)
urllib.request.urlopen(request, timeout=10).close()
"""


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: password", function=_set_password, app=app)


def _set_password(app: App):
    password = host_vars()["knightloader_password"]
    # The app answers once it is up, a little after its unit starts
    run.retry(
        lambda: run.run(
            f"podman exec -i {app.name}-web python3 -c {shlex.quote(SET_PASSWORD)}",
            stdin=f"{password}\n",
            secret=True,
            sudo=app.become,
        ),
        retries=60,
    )
