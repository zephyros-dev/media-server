"""Put file contents and directories on the host, checking all of an app's paths in one
round trip. files.put and files.directory look up each path (and, for put, its checksum
and its directory) on their own"""

import hashlib
from io import StringIO

from pyinfra import host
from pyinfra.api import (
    FactBase,
    FileUploadCommand,
    QuoteString,
    StringCommand,
    operation,
)
from pyinfra.operations.util import files as file_utils


class FileStates(FactBase):
    """`{path: (sha256, mode)}` of the files that exist among `paths`"""

    def command(self, paths: list[str]):
        return StringCommand(
            "for p in",
            *(QuoteString(path) for path in paths),
            '; do [ -f "$p" ] && echo "$(sha256sum "$p" | cut -d" " -f1)'
            ' $(stat -c %a "$p") $p"; done; true',
        )

    @staticmethod
    def default():
        # No output when none of the paths exists, e.g. the first deploy of an app
        return {}

    def process(self, output):
        states = {}
        for line in output:
            checksum, mode, path = line.split(" ", 2)
            states[path] = (checksum, mode)
        return states


class DirectoryModes(FactBase):
    """`{path: mode}` of the directories that exist among `paths`"""

    def command(self, paths: list[str]):
        return StringCommand(
            "for p in",
            *(QuoteString(path) for path in paths),
            '; do [ -d "$p" ] && echo "$(stat -c %a "$p") $p"; done; true',
        )

    @staticmethod
    def default():
        return {}

    def process(self, output):
        return {path: mode for mode, path in (line.split(" ", 1) for line in output)}


@operation()
def directories(paths: dict[str, str | None]):
    """Create the directories of `paths`, like files.directory. A directory that exists only
    changes when its mode in `paths` isn't None and differs

    + paths: {path: mode or None}
    """
    existing = host.get_fact(DirectoryModes, paths=list(paths))
    for path, mode in paths.items():
        if path not in existing:
            yield StringCommand("mkdir -p", QuoteString(path))
        elif mode is None or existing[path] == mode:
            continue
        if mode:
            yield file_utils.chmod(path, mode)


@operation()
def put(content: str, dest: str, mode: str, states: dict[str, tuple[str, str]]):
    """Upload `content` to `dest` unless it already has that content and `mode`

    + states: FileStates of the app's files
    """
    checksum = hashlib.sha256(content.encode()).hexdigest()
    if states.get(dest) == (checksum, mode):
        return
    yield FileUploadCommand(
        StringIO(content), dest, remote_temp_filename=host.get_temp_filename(dest)
    )
    yield file_utils.chmod(dest, mode)


def states(paths: list[str], sudo: bool) -> dict[str, tuple[str, str]]:
    return host.get_fact(FileStates, paths=paths, _sudo=sudo)
