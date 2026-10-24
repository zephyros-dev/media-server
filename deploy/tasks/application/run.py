"""Helpers for the app flows that act on what a running container reports. They run inside
python.call, at execution time: when the deploy is planned the unit may not even be started"""

import json
import shlex
import time
from collections.abc import Callable

from pyinfra import host
from pyinfra.api import StringCommand


class CommandError(Exception):
    pass


def run(command: str, stdin: str | None = None, check=True, secret=False, sudo=False):
    """Run `command` on the host and return its output (`.stdout`, `.stdout_lines`)

    + stdin: written to the command's stdin, the way to pass secrets without them in argv
    + secret: keep the command out of the error, when a secret is in it
    """
    arguments = {"_sudo": sudo}
    if stdin is not None:
        arguments["_stdin"] = stdin
    ok, output = host.run_shell_command(StringCommand(command), **arguments)
    if check and not ok:
        shown = "<secret command>" if secret else command
        stderr = "\n".join(output.stderr_lines)
        raise CommandError(f"{shown} failed:\n{stderr}")
    return ok, output


def retry[T](function: Callable[[], T], retries: int, delay: int = 5) -> T:
    """Call `function` until it doesn't raise, like ansible's until/retries/delay"""
    for attempt in range(retries + 1):
        try:
            return function()
        except Exception:
            if attempt == retries:
                raise
            time.sleep(delay)
    raise AssertionError("unreachable")


def systemctl(action: str, unit: str, become: bool):
    run(f"systemctl {'' if become else '--user '}{action} {unit}", sudo=become)


def read(path: str, sudo=False) -> str | None:
    """The file's content, None if it doesn't exist"""
    ok, output = run(f"cat {shlex.quote(path)}", check=False, sudo=sudo)
    return "\n".join(output.stdout_lines) + "\n" if ok else None


def write(path: str, content: str, mode: str | None = None, sudo=False):
    """Write `content` to `path`. Without `mode`, an existing file keeps its mode and owner"""
    quoted = shlex.quote(path)
    chmod = f" && chmod {mode} {quoted}" if mode else ""
    run(f"cat > {quoted}{chmod}", stdin=content, sudo=sudo)


def exists(path: str, sudo=False) -> bool:
    return run(f"test -e {shlex.quote(path)}", check=False, sudo=sudo)[0]


def curl_json(
    url: str,
    headers: dict | None = None,
    body: dict | None = None,
    form: dict | None = None,
    method: str | None = None,
    container: str | None = None,
    sudo=False,
):
    """A request from the host, or from inside `container` when it isn't reachable from the
    host. The url, headers and body go through a curl config on stdin, so tokens and
    passwords stay out of argv

    + form: url-encoded form fields instead of a JSON body
    + method: defaults to curl's, POST with a body or form

    An empty response (204) gives None
    """
    # max-time: ansible's uri timeout, so a hung server fails the attempt instead of hanging
    config = [
        f"url = {json.dumps(url)}",
        "fail",
        "silent",
        "show-error",
        "max-time = 30",
    ]
    if method:
        config.append(f"request = {json.dumps(method)}")
    config += [
        f"header = {json.dumps(f'{k}: {v}')}" for k, v in (headers or {}).items()
    ]
    if body is not None:
        config += [
            'header = "Content-Type: application/json"',
            f"data = {json.dumps(json.dumps(body))}",
        ]
    config += [
        f"data-urlencode = {json.dumps(f'{k}={v}')}" for k, v in (form or {}).items()
    ]
    command = f"podman exec -i {container} curl" if container else "curl"
    _, output = run(
        f"{command} --config -", stdin="\n".join(config) + "\n", secret=True, sudo=sudo
    )
    return json.loads(output.stdout) if output.stdout.strip() else None
