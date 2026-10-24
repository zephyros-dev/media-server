"""Each app runs as a kube quadlet, with a .build unit per image built from
deploy/tasks/application/files/<app>/<image>/"""

import importlib
import importlib.util
import os
from dataclasses import dataclass
from io import StringIO
from pathlib import Path
from types import ModuleType

from pyinfra import host
from pyinfra.facts.files import FindDirectories, FindFiles, FindLinks
from pyinfra.facts.server import Home
from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from deploy.tasks.common.templates import render
from deploy.tasks.system import systemctl as systemd_ops

APP_FILES = Path(__file__).parent / "files"


@dataclass
class App:
    """An app of the cue `application` output, as the custom flows see it"""

    key: str
    name: str
    data: dict
    become: bool
    quadlet_dir: str

    def service(self):
        """The generic deploy, which a custom flow runs at the point it needs it"""
        _service(self.key, self.name, self.data, self.quadlet_dir, self.become)


def _flow(key: str) -> ModuleType | None:
    """deploy/tasks/application/service/<app>.py, the app's custom flow if it has one"""
    module = f"deploy.tasks.application.service.{key}"
    return importlib.import_module(module) if importlib.util.find_spec(module) else None


def deploy(key: str, app: dict):
    """Deploy or remove the app `key` of the cue `application` output"""
    # Imported here: they import App from this module
    from deploy.tasks.application import arr, postgres

    if app["pod"] is None:
        return
    name = key.replace("_", "-")
    become = app["param"]["become"]
    quadlet_dir = (
        "/etc/containers/systemd"
        if become
        else f"{host.get_fact(Home)}/.config/containers/systemd"
    )

    state = app["transform"]["state"]
    if state == "started":
        target = App(key, name, app, become, quadlet_dir)
        postgres_action = app["param"]["postgres_action"]
        # Like ansible, a postgres action runs the generic deploy, not the custom flow
        flow = _flow(key) if postgres_action == "none" else None
        _volumes(name, app, become)
        if flow:
            flow.deploy(target)
        else:
            target.service()
        if postgres_action != "none":
            postgres.deploy(target, postgres_action)
        if arr.applies(name):
            arr.deploy(target)
    elif state == "absent":
        _remove(name, quadlet_dir, become)


def _volumes(name: str, app: dict, become: bool):
    if "volumes" not in app["param"]:
        return
    for volume in app["transform"]["volumes"].values():
        path = volume["value"]
        if (
            volume["type"] in ("relativePathDir", "absolutePathDir")
            and "/dev/" not in path
        ):
            # No mode: like ansible, leave the mode of an existing volume alone
            files.directory(
                name=f"{name}: volume {path}", path=path, present=True, _sudo=become
            )
        elif volume["type"] == "file":
            files.directory(
                name=f"{name}: volume dir {os.path.dirname(path)}",
                path=os.path.dirname(path),
                mode="755",
                _sudo=become,
            )
            files.file(
                name=f"{name}: volume {path}", path=path, mode="600", _sudo=become
            )


def _service(key: str, name: str, app: dict, quadlet_dir: str, become: bool):
    app_dir = f"{quadlet_dir}/{name}"
    context = {"application_name": name, "application_item": {"key": key, "value": app}}

    def put(content: str, dest: str):
        return files.put(
            name=f"{name}: {os.path.relpath(dest, quadlet_dir)}",
            src=StringIO(content),
            dest=dest,
            mode="600",
            _sudo=become,
        )

    files.directory(name=f"{name}: quadlet dir", path=app_dir, mode="755", _sudo=become)

    # files/<app>/<image>/ -> <quadlet>/<app>/<image>/, one build unit per <image> dir.
    # Images pinned in deploy/cue/images.cue are pulled by podman kube play instead
    image_ops = []
    repo_images = set()
    local_dir = APP_FILES / name
    if local_dir.is_dir():
        repo_images = {p.name for p in local_dir.iterdir() if p.is_dir()}
        image_ops.append(
            files.sync(
                name=f"{name}: Containerfiles",
                src=str(local_dir),
                dest=app_dir,
                mode="600",
                dir_mode="755",
                add_deploy_dir=False,
                _sudo=become,
            )
        )

    # Any other image dir on the host is left over from an image that was pinned, renamed or
    # dropped: its .build would still be RequiredBy the app and rebuild it on every start
    remote_images = {
        os.path.basename(path)
        for path in host.get_fact(
            FindDirectories, path=app_dir, maxdepth=1, _sudo=become
        )
        if path.rstrip("/") != app_dir
    }
    stale_builds = []
    for image in sorted(repo_images | remote_images):
        build = f"{quadlet_dir}/{image}.build"
        if image in repo_images:
            content = render(
                "quadlet/image.build.j2",
                {**context, "item": {"path": f"{app_dir}/{image}"}},
            )
            image_ops.append(put(content, build))
        else:
            stale_builds.append(
                files.file(
                    name=f"{name}: remove {image}.build",
                    path=build,
                    present=False,
                    _sudo=become,
                )
            )

    kube_yaml = put(app["manifest"], f"{app_dir}/deployment.yaml")
    kube = put(render("quadlet/service.kube.j2", context), f"{quadlet_dir}/{name}.kube")

    systemd.daemon_reload(
        name=f"{name}: daemon-reload",
        user_mode=not become,
        _sudo=become,
        _if=any_changed(kube_yaml, kube, *image_ops, *stale_builds),
    )
    changed = any_changed(kube_yaml, kube, *image_ops)
    for state, condition in (
        ("restarted", changed),
        ("started", lambda: not changed()),
    ):
        systemd_ops.service(
            name=f"{name}: {state}",
            service=name,
            state=state,
            user_mode=not become,
            # Queue the job and move on, since it can block on the image build unit. Not for
            # a custom flow: like in ansible, its next steps exec into the started container
            no_block=_flow(key) is None,
            _sudo=become,
            _if=condition,
        )


def _remove(name: str, quadlet_dir: str, become: bool):
    # Same `<app>*` glob as ansible: it catches the app's .kube, its folder and the .build
    # units of its images (named after the image, e.g. paperless-ngx.build)
    def find(fact):
        return host.get_fact(
            fact, path=quadlet_dir, maxdepth=1, fname=f"{name}*", _sudo=become
        )

    found_files = find(FindFiles)
    found_links = find(FindLinks)
    found_dirs = find(FindDirectories)
    if not (found_files or found_links or found_dirs):
        return

    systemd_ops.service(
        name=f"{name}: stop",
        service=name,
        state="stopped",
        user_mode=not become,
        _sudo=become,
    )
    for path in found_files:
        basename = os.path.basename(path)
        if basename.endswith(".build"):
            systemd_ops.service(
                name=f"{name}: stop {basename}",
                service=basename.replace(".", "-"),
                state="stopped",
                user_mode=not become,
                _sudo=become,
            )
    for path in found_files:
        files.file(
            name=f"{name}: remove {path}", path=path, present=False, _sudo=become
        )
    for path in found_links:
        files.link(
            name=f"{name}: remove {path}", path=path, present=False, _sudo=become
        )
    for path in found_dirs:
        files.directory(
            name=f"{name}: remove {path}", path=path, present=False, _sudo=become
        )
    systemd.daemon_reload(
        name=f"{name}: daemon-reload", user_mode=not become, _sudo=become
    )
