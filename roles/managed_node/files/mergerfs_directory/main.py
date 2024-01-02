import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(
    description="directory sync/clean between mergerfs disks"
)
parser.add_argument(
    "--config-file",
    help="Config file location",
    default="config.json",
)


args = parser.parse_args()


def create_dirtree_without_files(src, dst):
    Path(dst).mkdir(parents=True, exist_ok=True)
    for root, dirs, files in Path.walk(src):
        for dirname in dirs:
            dirpath = Path(dst, Path(root, dirname).relative_to(src))
            Path(dirpath).mkdir(parents=True, exist_ok=True)


def mergerfs_mkdir(
    mergerfs_disks_names: list,
    mergerfs_disks_storage_path: str,
    mergerfs_storage_path: str,
    mkdir_paths: list,
):
    for mkdir_path in mkdir_paths:
        for mergerfs_disks_name in mergerfs_disks_names:
            create_dirtree_without_files(
                src=Path(mergerfs_storage_path, mkdir_path),
                dst=Path(mergerfs_disks_storage_path, mergerfs_disks_name, mkdir_path),
            )


if __name__ == "__main__":
    with open(args.config_file, "r") as config_file:
        config = json.load(config_file)

    mergerfs_mkdir(
        mergerfs_disks_names=config["mergerfs_disks_name"],
        mergerfs_disks_storage_path=config["mergerfs_disks_storage_path"],
        mergerfs_storage_path=config["mergerfs_storage_path"],
        mkdir_paths=config["mkdir_paths"],
    )
