"""The mergerfs-directory script and its config, run by the mergerfs-directory timer"""

import json
from io import StringIO
from pathlib import Path

from pyinfra import host
from pyinfra.facts.files import FileContents
from pyinfra.operations import files

from deploy.common.facts import host_vars
from deploy.host.common import user_dir


def _merge(base: dict, edit: dict) -> dict:
    """Ansible's `combine(recursive=true)`"""
    merged = dict(base)
    for key, value in edit.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            value = _merge(merged[key], value)
        merged[key] = value
    return merged


def deploy():
    v = host_vars()
    config_dir = f"{user_dir()}/.config/mergerfs_directory"

    files.directory(name="mergerfs scripts folder", path=config_dir, mode="755")
    files.put(
        name="mergerfs script",
        src=str(Path(__file__).parents[1] / "files/mergerfs_directory/main.py"),
        dest=f"{config_dir}/main.py",
        mode="755",
    )

    # A recursive merge: keep what else the config has, set these keys
    config_path = f"{config_dir}/config.json"
    current = host.get_fact(FileContents, path=config_path)
    config = _merge(
        json.loads("\n".join(current)) if current else {},
        {
            "mergerfs_disks_name": v["disks"]["storage"]["disks_list"],
            "mergerfs_disks_storage_path": v["global_disks_storage_path"],
            "mergerfs_storage_path": v["global_storage"],
            "mkdir_paths": v["global_storage_mergerfs_mkdir_paths"],
        },
    )
    files.put(
        name="mergerfs config",
        # Ansible's to_nice_json
        src=StringIO(json.dumps(config, indent=4, sort_keys=True)),
        dest=config_path,
        mode="644",
    )
