"""arr apps (lidarr, prowlarr, radarr): forms login with the caddy SSO user and password,
since the apps dropped basic auth"""

import re

from pyinfra.operations import python

from deploy.application import run
from deploy.application.quadlet import App
from deploy.common.facts import host_vars

# The API version of each app's /config/host
API_VERSIONS = {"radarr": "v3"}
DEFAULT_API_VERSION = "v1"


def applies(name: str) -> bool:
    return "arr" in name and name != "bazarr"


def deploy(app: App):
    python.call(
        name=f"{app.name}: forms authentication",
        function=_authenticate,
        app=app,
    )


def _authenticate(app: App):
    v = host_vars()
    path = f"{app.data['transform']['volumes']['config']['value']}/config.xml"

    # The app writes config.xml on its first start, which may still be coming or be half
    # written (ansible's xml module retried until the file parsed)
    def read_api_key() -> str:
        content = run.read(path, sudo=app.become)
        match = content and re.search(r"<ApiKey>([^<]+)</ApiKey>", content)
        if not match:
            raise FileNotFoundError(f"{path} missing or incomplete")
        return match.group(1)

    api_key = run.retry(read_api_key, retries=60)
    version = API_VERSIONS.get(app.name, DEFAULT_API_VERSION)
    url = (
        f"http://localhost:{app.data['param']['caddy_proxy']}/api/{version}/config/host"
    )

    def request(suffix="", **kwargs):
        # From inside the container: on a bridge network, the host can't reach the app
        return run.curl_json(
            url + suffix,
            headers={"X-Api-Key": api_key},
            container=f"{app.name}-web",
            sudo=app.become,
            **kwargs,
        )

    # The API answers once the app is up, a little after it wrote its config
    current = run.retry(request, retries=60)
    # Always set: the API never returns the password, so there's no telling if it's right
    request(
        f"/{current['id']}",
        method="PUT",
        body={
            **current,
            "authenticationMethod": "forms",
            "authenticationRequired": "enabled",
            "username": v["caddyfile_auth_user"],
            "password": v["caddyfile_auth_pass"],
            "passwordConfirmation": v["caddyfile_auth_pass"],
        },
    )
