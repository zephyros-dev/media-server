"""Each app runs as a kube quadlet, with a .build unit per image built from
deploy/tasks/application/files/<app>/<image>/"""

import importlib
import importlib.util
import os
from dataclasses import dataclass
from pathlib import Path
from types import ModuleType

from pyinfra import host
from pyinfra.facts.files import FindDirectories, FindFiles, FindLinks
from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from deploy.tasks.application import content
from deploy.tasks.common.facts import host_vars
from deploy.tasks.common.templates import render
from deploy.tasks.system import systemctl as systemd_ops

APP_FILES = Path(__file__).parent / "files"

# The quadlet dirs already ensured, per host: every app puts files in it, so it is
# ensured once, not by each app
_ensured_dirs: set[tuple[str, str]] = set()


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
        else f"{host_vars()['host']['home']}/.config/containers/systemd"
    )

    state = app["transform"]["state"]
    if state == "started":
        if (host.name, quadlet_dir) not in _ensured_dirs:
            _ensured_dirs.add((host.name, quadlet_dir))
            files.directory(
                name=f"quadlet dir {quadlet_dir}",
                path=quadlet_dir,
                present=True,
                _sudo=become,
            )
        target = App(key, name, app, become, quadlet_dir)
        postgres_action = app["param"]["postgres_action"]
        # Like ansible, a postgres action runs the generic deploy, not the custom flow
        flow = _flow(key) if postgres_action == "none" else None
        _directories(name, app, f"{quadlet_dir}/{name}", become)
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


def _directories(name: str, app: dict, app_dir: str, become: bool):
    """The app's dir and its volume dirs, checked in one lookup"""
    # No mode for a volume: like ansible, leave the mode of an existing one alone
    paths: dict[str, str | None] = {app_dir: "755"}
    volumes = app["transform"]["volumes"].values() if "volumes" in app["param"] else ()
    for volume in volumes:
        path = volume["value"]
        if (
            volume["type"] in ("relativePathDir", "absolutePathDir")
            and "/dev/" not in path
        ):
            paths.setdefault(path, None)
        elif volume["type"] == "file":
            paths[os.path.dirname(path)] = "755"
    content.directories(name=f"{name}: directories", paths=paths, _sudo=become)
    for volume in volumes:
        if volume["type"] == "file":
            files.file(
                name=f"{name}: volume {volume['value']}",
                path=volume["value"],
                mode="600",
                _sudo=become,
            )


def _service(key: str, name: str, app: dict, quadlet_dir: str, become: bool):
    app_dir = f"{quadlet_dir}/{name}"
    context = {"application_name": name, "application_item": {"key": key, "value": app}}

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
    # Everything put on the host, in order: the build units, then the manifest and the unit
    contents: dict[str, str] = {}
    stale_builds = []
    for image in sorted(repo_images | remote_images):
        build = f"{quadlet_dir}/{image}.build"
        if image in repo_images:
            contents[build] = render(
                "quadlet/image.build.j2",
                {**context, "item": {"path": f"{app_dir}/{image}"}},
            )
        else:
            stale_builds.append(
                files.file(
                    name=f"{name}: remove {image}.build",
                    path=build,
                    present=False,
                    _sudo=become,
                )
            )
    contents[f"{app_dir}/deployment.yaml"] = app["manifest"]
    contents[f"{quadlet_dir}/{name}.kube"] = render("quadlet/service.kube.j2", context)

    states = content.states(list(contents), become)
    puts = {
        dest: content.put(
            name=f"{name}: {os.path.relpath(dest, quadlet_dir)}",
            content=text,
            dest=dest,
            mode="600",
            states=states,
            _sudo=become,
        )
        for dest, text in contents.items()
    }
    kube_yaml = puts[f"{app_dir}/deployment.yaml"]
    kube = puts[f"{quadlet_dir}/{name}.kube"]
    image_ops += [op for dest, op in puts.items() if dest.endswith(".build")]

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
