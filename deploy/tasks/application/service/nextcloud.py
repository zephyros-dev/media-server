"""Install on a fresh host, upgrade,
system config and the nextcloud apps, all through occ"""

import json
import re
import shlex

from pyinfra.operations import python

from deploy.tasks.application import run
from deploy.tasks.application.quadlet import App
from deploy.tasks.common.facts import host_vars

OCC = "podman exec --user www-data nextcloud-web php occ"


def _apps(domain: str) -> dict:
    """App name -> {state: present|absent, config: {key: value}}"""
    return {
        "bookmarks": {},
        "richdocuments": {
            "config": {
                "public_wopi_url": f"https://nextcloud-office.{domain}",
                "wopi_allowlist": "0.0.0.0/0",
                "wopi_url": f"https://nextcloud-office.{domain}",
            },
        },
        "tasks": {},
    }


def deploy(app: App):
    app.service()
    python.call(name=f"{app.name}: occ setup", function=_setup)


def occ(command: str, check=True, secret=False):
    return run.run(f"{OCC} {command}", check=check, secret=secret)


def _setup():
    v = host_vars()
    domain = v["server_domain"]

    # occ is unusable until the image entrypoint has finished copying the nextcloud
    # sources into the volume on first start
    _, status = run.retry(lambda: occ("status --output=json"), retries=60)
    installed = json.loads(re.search(r"\{.*\}", status.stdout)[0])["installed"]

    if not installed:
        # Postgres 15+ only lets the database owner create in schema public. The installer
        # connects as postgres but creates its own oc_<admin> role and builds the tables as
        # that, which fails with "Insufficient privilege". The role doesn't exist yet, so
        # grant on the schema instead; this database belongs to nextcloud's pod alone.
        # https://github.com/nextcloud/docker/issues/1880
        # Retried: on a fresh host postgres may still be initializing when occ answers
        run.retry(
            lambda: run.run(
                "podman exec nextcloud-postgres psql --username=postgres"
                " --dbname=nextcloud --command='GRANT ALL ON SCHEMA public TO PUBLIC;'"
            ),
            retries=30,
        )
        # Fresh host (e.g. a rebuilt staging): install unattended instead of leaving the
        # instance at the web installer
        occ(
            "maintenance:install --database pgsql --database-host localhost:5432"
            " --database-name nextcloud --database-user postgres"
            f" --database-pass {shlex.quote(v['nextcloud_postgres_password'])}"
            f" --admin-user {shlex.quote(v['nextcloud_admin_user'])}"
            f" --admin-pass {shlex.quote(v['nextcloud_admin_password'])}",
            secret=True,
        )

    for command in (
        "upgrade",
        "maintenance:mode --off",
        "app:update --all",
        "background:cron",
        "db:add-missing-indices",
    ):
        occ(command)

    _, network = run.run("podman network inspect podman-default-kube-network")
    subnet = json.loads(network.stdout)[0]["subnets"][0]["subnet"]
    for setting in (
        "maintenance_window_start --type=integer --value=6",
        f"trusted_domains 0 --value={shlex.quote(f'nextcloud.{domain}')}",
        # Warning and above; 0 (debug) grew nextcloud.log to 63GB
        "loglevel --type=integer --value=2",
        # Rotated by the OC\Log\Rotate background job (nextcloud-cron timer), keeps one .1
        "log_rotate_size --type=integer --value=104857600",
        f"trusted_proxies 0 --value={shlex.quote(subnet)}",
    ):
        occ(f"config:system:set {setting}")

    for name, settings in _apps(domain).items():
        if settings.get("state", "present") == "present":
            ok, output = occ(f"app:install {name}", check=False)
            if not (ok or "already installed" in output.stdout):
                raise run.CommandError(f"app:install {name} failed:\n{output.output}")
            # Force enable app even if it is not available for new nextcloud version
            occ(f"app:enable --force {name}")
            for key, value in settings.get("config", {}).items():
                occ(f"config:app:set --value {shlex.quote(value)} {name} {key}")
        else:
            ok, output = occ(f"app:remove {name}", check=False)
            if not (ok or "not installed" in output.stdout):
                raise run.CommandError(f"app:remove {name} failed:\n{output.output}")
