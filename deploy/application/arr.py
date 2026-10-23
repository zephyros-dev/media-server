"""arr apps (lidarr, prowlarr, radarr): no login from the LAN"""

import re

from pyinfra.operations import python

from deploy.application import run
from deploy.application.quadlet import App

AUTHENTICATION = "DisabledForLocalAddresses"


def applies(name: str) -> bool:
    return "arr" in name and name != "bazarr"


def deploy(app: App):
    python.call(
        name=f"{app.name}: disable authentication for local addresses",
        function=_disable_authentication,
        app=app,
    )


def _disable_authentication(app: App):
    path = f"{app.data['transform']['volumes']['config']['value']}/config.xml"

    # The app writes config.xml on its first start, which may still be coming or be half
    # written (ansible's xml module retried until the file parsed)
    def read() -> str:
        content = run.read(path, sudo=app.become)
        if content is None or "</Config>" not in content:
            raise FileNotFoundError(f"{path} missing or incomplete")
        return content

    content = run.retry(read, retries=60)
    element = f"<AuthenticationRequired>{AUTHENTICATION}</AuthenticationRequired>"
    # A text edit rather than an xml rewrite, so the rest of the file keeps its formatting
    updated, count = re.subn(
        r"<AuthenticationRequired>[^<]*</AuthenticationRequired>", element, content
    )
    if not count:
        updated = content.replace("</Config>", f"  {element}\n</Config>")
    if updated == content:
        return
    run.write(path, updated, sudo=app.become)
    run.systemctl("restart", app.name, app.become)
