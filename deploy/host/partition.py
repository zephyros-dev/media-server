"""One GPT partition spanning each disk of `disks`, with its
filesystem. Like ansible's parted and filesystem modules, existing partitions and
filesystems are kept, and a filesystem of another type fails the deploy. Unlike them, a disk
with a non-GPT table fails instead of being relabelled (which wipes it). On the server, run
`deploy/partition.py` with --dry first"""

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import server

from deploy.common.facts import host_vars

# The filesystem module's force flags: blkid saw no filesystem, so stale signatures blkid
# doesn't report mustn't make mkfs refuse or prompt
MKFS_FORCE = {"ext4": "-F", "btrfs": "-f"}


def _probe(tag: str, device: str) -> str:
    return host.get_fact(
        Command,
        f"blkid --probe --match-tag {tag} --output value {device} || true",
        _sudo=True,
    )


def deploy():
    for group, settings in host_vars()["disks"].items():
        fs_type = settings["fs_type"]
        for disk in settings["disks_list"]:
            device = f"/dev/disk/by-id/{disk}"
            partition = f"{device}-part1"
            has_partition = (
                host.get_fact(Command, f"test -e {partition} && echo yes || echo no")
                == "yes"
            )
            table = _probe("PTTYPE", device)
            if table and table != "gpt":
                raise ValueError(
                    f"{group} disk {disk} has a {table} partition table, not gpt."
                    " Relabelling wipes it: do it by hand if that's intended"
                )

            if not has_partition:
                # Like the parted module: a new label only on a disk without a table, so an
                # existing gpt disk keeps its other partitions (and mkpart fails on overlap)
                label = "" if table else " mklabel gpt"
                server.shell(
                    name=f"Partition {group} disk {disk}",
                    commands=[
                        (
                            f"parted --script --fix {device}{label}"
                            f" mkpart primary {fs_type} 0% 100%"
                        ),
                        f"udevadm settle --exit-if-exists={partition}",
                    ],
                    _sudo=True,
                )
                filesystem = ""
            else:
                filesystem = _probe("TYPE", partition)
            if filesystem and filesystem != fs_type:
                raise ValueError(
                    f"{group} disk {disk} is already used as {filesystem}, not {fs_type}"
                )
            if not filesystem:
                server.shell(
                    name=f"Make {fs_type} filesystem on {group} disk {disk}",
                    commands=[f"mkfs.{fs_type} {MKFS_FORCE[fs_type]} {partition}"],
                    _sudo=True,
                )
