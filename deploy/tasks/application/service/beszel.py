"""Connect the agent to the hub without the web UI. The agent's
token is generated ahead in beszel.sops.yaml and enabled here as a permanent universal token,
and the hub's public key (only known once it has started) is written to the file the agent
reads (KEY_FILE)"""

from urllib.parse import quote

from pyinfra.operations import python

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.facts import host_vars

API = "http://localhost:8090/api"


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: connect the agent", function=_connect, app=app)


def _connect(app: App):
    v = host_vars()
    run.retry(lambda: run.curl_json(f"{API}/health"), retries=60)

    # The first user, created by the hub from USER_EMAIL/USER_PASSWORD
    auth = run.curl_json(
        f"{API}/collections/users/auth-with-password",
        body={
            "identity": f"admin@{v['server_domain']}",
            "password": v["beszel_user_password"],
        },
    )
    headers = {"Authorization": auth["token"]}

    key = run.curl_json(f"{API}/beszel/getkey", headers=headers)["key"]
    key_file = f"{v['global_volume_path']}/beszel/agent/hub_key"
    key_changed = run.read(key_file) != f"{key}\n"
    if key_changed:
        run.write(key_file, f"{key}\n", mode="600")

    # Idempotent: upserts the user's permanent token with this value
    token = quote(v["beszel_agent_token"], safe="")
    run.curl_json(
        f"{API}/beszel/universal-token?enable=1&permanent=1&token={token}",
        headers=headers,
    )

    # The agent only reads its key at startup (until the key exists it keeps exiting)
    if key_changed:
        run.systemctl("restart", app.name, app.become)
