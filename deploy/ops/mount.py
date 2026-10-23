"""fstab mounts, like ansible.posix.mount with state mounted"""

import re

from pyinfra import host
from pyinfra.api import QuoteString, StringCommand, operation
from pyinfra.facts.files import FindInFile
from pyinfra.facts.server import Command
from pyinfra.operations import files


@operation()
def mounted(path: str, src: str, fstype: str, opts="defaults"):
    """Write the fstab entry of `path` and mount it. A changed entry of a mounted `path`
    is remounted, like ansible does"""
    entry = f"{src} {path} {fstype} {opts} 0 0"
    # The second fstab field is the mount point. A basic regex for grep and sed, so no `+`
    # (a literal there): re.escape escapes characters like '-' that grep warns about
    path_regex = re.sub(r"([.\[\]*^$\\])", r"\\\1", path)
    match = (
        rf"^[^[:space:]][^[:space:]]*[[:space:]][[:space:]]*{path_regex}[[:space:]].*$"
    )
    in_fstab = host.get_fact(FindInFile, path="/etc/fstab", pattern=match)
    is_mounted = (
        host.get_fact(Command, f"mountpoint -q {path} && echo true || echo false")
        == "true"
    )

    if in_fstab != [entry]:
        yield from files.line._inner(path="/etc/fstab", line=match, replace=entry)
        if is_mounted:
            yield StringCommand("mount", "-o", "remount", QuoteString(path))
    if not is_mounted:
        yield StringCommand("mkdir", "-p", QuoteString(path))
        yield StringCommand("mount", QuoteString(path))
