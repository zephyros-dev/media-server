"""Install zapret2 on the routers: the release's files, with the settings of
group_data/openwrt applied to its config.default

    uv run pyinfra deploy/inventory.py deploy/tasks/openwrt/main.py --limit openwrt [--dry]
"""

import re
import shutil
import tarfile
import urllib.request
from io import StringIO
from pathlib import Path

import yaml
from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import files, server
from pyinfra.operations.util import any_changed

from deploy.tasks.common.data import REPO

DEST = "/opt/zapret2"
# The only architecture of the routers, the other binaries aren't copied
ARCHITECTURES = ["linux-arm64"]


def _release(version: str) -> Path:
    """The extracted release, downloaded on a new version"""
    cache = REPO / ".decrypted/zapret"
    release = cache / f"zapret2-{version}"
    if not release.exists():
        print(f"New version detected {version}")
        url = (
            "https://github.com/bol-van/zapret2/releases/download/"
            f"{version}/zapret2-{version}-openwrt-embedded.tar.gz"
        )
        cache.mkdir(parents=True, exist_ok=True)
        archive = cache / f"zapret2-{version}.tar.gz"
        urllib.request.urlretrieve(url, archive)
        with tarfile.open(archive) as tar:
            tar.extractall(cache, filter="data")
    for binaries in (release / "binaries").iterdir():
        if binaries.is_dir() and binaries.name not in ARCHITECTURES:
            shutil.rmtree(binaries)
    return release


def _assignment(key: str, value: str) -> str:
    """`KEY=value`, quoted only with a space: how the installer writes the config, which
    it rewrites on install. Another form would be a change on every deploy"""
    return f'{key}="{value}"' if " " in value else f"{key}={value}"


def _first_config(default: str, settings: dict[str, str]) -> str:
    """config.default with the settings, for a router that has no config yet"""
    for key, value in settings.items():
        line = _assignment(key, value)
        default, count = re.subn(
            rf"^{re.escape(key)}=.*$",
            lambda _, line=line: line,
            default,
            flags=re.MULTILINE,
        )
        if not count:
            default += f"{line}\n"
    return default


# # Need to create custom user include list since headless service fail those domain during the first call and do not retry for autohostlist
# # https://github.com/bol-van/zapret/blob/master/docs/readme.en.md#autohostlist-mode
# Path(f".decrypted.zapret/zapret2-{version}/ipset/zapret-hosts-user.txt").write_text(
#     openwrt_config["custom_user_include"]
# )

version = yaml.safe_load((REPO / "deploy/tasks/openwrt/dependencies.yaml").read_text())[
    "bol-van/zapret2"
]
release = _release(version)

INIT = "/etc/init.d/zapret2"
CONFIG = f"{DEST}/config"


def _answer(command: str) -> bool:
    return host.get_fact(Command, f"{command} && echo yes || echo no") == "yes"


running = _answer("pidof nfqws2 > /dev/null")
installed = _answer(f"test -e {INIT}")
has_config = _answer(f"test -f {CONFIG}")

# A running binary can't be overwritten (scp: Text file busy, where rsync replaced the file),
# so a running zapret2 is stopped for the update, only when there is one. The install below
# starts it again
server.shell(
    name="Stop zapret2 for the update",
    commands=[f"{INIT} stop"],
    _if=lambda: running and sync.will_change,
)
sync = files.sync(
    name=f"zapret2 {version}",
    src=str(release),
    dest=DEST,
    user="root",
    group="root",
    delete=True,
    # What isn't in the release but the installer and the service create: the config (below),
    # the user lists, the downloaded lists, the temp files. Deleting them is a change on
    # every deploy, and the install that follows creates them again. These match the
    # remote paths only, the release has no such files
    exclude=[
        "*/.git/*",
        CONFIG,
        f"{DEST}/ipset/*.txt",
        f"{DEST}/ipset/*.txt.gz",
        f"{DEST}/ipset/*.log",
        f"{DEST}/tmp/*",
        # The binaries the installer copies from binaries/<architecture> (install_bin.sh)
        f"{DEST}/nfq2/nfqws2",
        f"{DEST}/mdig/mdig",
        f"{DEST}/ip2net/ip2net",
    ],
)

# The installer writes its own variables into the config (FWTYPE, GETLIST, ...), so after
# the first install only our settings are kept, in place, and the rest is left alone
first_config = files.put(
    name="zapret2 config",
    src=StringIO(
        _first_config((release / "config.default").read_text(), host.data.config)
    ),
    dest=CONFIG,
    user="root",
    group="root",
    mode="644",
    _if=lambda: not has_config,
)
settings = [
    files.line(
        name=f"zapret2 config {key}",
        path=CONFIG,
        line=rf"^{key}=.*$",
        replace=_assignment(key, value),
        _if=lambda: has_config,
    )
    for key, value in host.data.config.items()
]

# Unattended: every question of the installer is read from stdin, where nothing answers,
# so each takes its default, which is what the config says. It installs the packages, the
# init script, the firewall hooks and the cron job, and starts the service
changed = any_changed(sync, first_config, *settings)
server.shell(
    name="Install zapret2",
    commands=[f"{DEST}/install_easy.sh < /dev/null"],
    _if=lambda: not installed or changed(),
)
