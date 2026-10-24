"""Btrfs data disks with a `data` and a
`content` subvolume each, pooled by mergerfs, plus the snapraid parity disks
(https://wiki.selfhosted.show/tools/snapraid-btrfs/)"""

from pyinfra import host
from pyinfra.facts.files import Directory
from pyinfra.operations import files, server

from deploy.tasks.common.facts import host_vars
from deploy.tasks.system import fstab

SUBVOLUMES = [
    # The actual data
    "data",
    # The snapraid content files
    "content",
]


def deploy():
    v = host_vars()
    for disk in v["disks"]["storage"]["disks_list"]:
        _storage_disk(disk)

    fstab.mounted(
        name="Mount the mergerfs storage pool",
        path="/mnt/storage",
        src=f"{v['global_disks_storage_path']}/*",
        fstype="mergerfs",
        opts="func.getattr=newest",
        _sudo=True,
    )
    for disk in v["disks"]["parity"]["disks_list"]:
        fstab.mounted(
            name=f"Mount parity disk {disk}",
            path=f"/mnt/disks/parity/{disk}",
            src=f"/dev/disk/by-id/{disk}-part1",
            fstype="ext4",
            _sudo=True,
        )

    user = v["host"]["user"]
    files.directory(
        name="Global storage owned by the user",
        path=v["global_storage"],
        mode="755",
        # By name, which pyinfra compares against. The user's primary group shares its name
        user=user,
        group=user,
        _sudo=True,
    )


def _storage_disk(disk: str):
    src = f"/dev/disk/by-id/{disk}-part1"
    root = f"/mnt/disks/storage/root/{disk}"
    fstab.mounted(
        name=f"Mount root subvolume of {disk}",
        path=root,
        src=src,
        fstype="btrfs",
        _sudo=True,
    )
    for subvolume in SUBVOLUMES:
        # The root isn't mounted yet on a new disk, so check again when creating it
        if not host.get_fact(Directory, path=f"{root}/{subvolume}", _sudo=True):
            server.shell(
                name=f"Create subvolume {subvolume} of {disk}",
                commands=[
                    f"test -e {root}/{subvolume} || btrfs subvolume create {root}/{subvolume}"
                ],
                _sudo=True,
            )
        fstab.mounted(
            name=f"Mount subvolume {subvolume} of {disk}",
            path=f"/mnt/disks/storage/{subvolume}/{disk}",
            src=src,
            fstype="btrfs",
            opts=f"subvol=/{subvolume},compress=zstd:1",
            _sudo=True,
        )
