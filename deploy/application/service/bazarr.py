"""Basic authentication with the caddy SSO user and password, through the settings API
the web UI uses. The API key comes from the config file the app writes on its first start"""

import hashlib

import yaml
from pyinfra.operations import python

from deploy.application import run
from deploy.application.quadlet import App
from deploy.common.facts import host_vars


def deploy(app: App):
    app.service()
    python.call(
        name=f"{app.name}: basic authentication", function=_authenticate, app=app
    )


def _authenticate(app: App):
    v = host_vars()
    path = f"{app.data['transform']['volumes']['config']['value']}/config/config.yaml"

    def read_api_key() -> str:
        content = run.read(path, sudo=app.become)
        if content is None:
            raise FileNotFoundError(f"{path} missing")
        return yaml.safe_load(content)["auth"]["apikey"]

    api_key = run.retry(read_api_key, retries=60)
    url = f"http://localhost:{app.data['param']['caddy_proxy']}/api/system/settings"

    def request(**kwargs):
        # From inside the container: on a bridge network, the host can't reach the app
        return run.curl_json(
            url,
            headers={"X-API-KEY": api_key},
            container=f"{app.name}-web",
            sudo=app.become,
            **kwargs,
        )

    # The API answers once the app is up, a little after it wrote its config
    auth = run.retry(request, retries=60)["auth"]
    # The app keeps the md5 of the password, which is what tells whether it's the right one
    password_md5 = hashlib.md5(v["caddyfile_auth_pass"].encode()).hexdigest()
    if (
        auth["type"] == "basic"
        and auth["username"] == v["caddyfile_auth_user"]
        and auth["password"] == password_md5
    ):
        return
    request(
        form={
            "settings-auth-type": "basic",
            "settings-auth-username": v["caddyfile_auth_user"],
            "settings-auth-password": v["caddyfile_auth_pass"],
        }
    )
