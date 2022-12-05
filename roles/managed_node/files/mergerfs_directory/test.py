import json
import os
import shutil
import unittest
from pathlib import Path

import main as main


def prepare_test(config):
    for mkdir_path in config["mkdir_paths"]:
        Path(config["mergerfs_storage_path"], mkdir_path).mkdir(
            parents=True, exist_ok=True
        )
    for mergerfs_disks_name in config["mergerfs_disks_names"]:
        Path(config["mergerfs_disks_storage_path"], mergerfs_disks_name).mkdir(
            parents=True, exist_ok=True
        )
    data_directory_0 = Path(
        config["mergerfs_storage_path"],
        config["mkdir_paths"][0],
        "directory_0",
    )
    data_directory_0.mkdir(parents=True, exist_ok=True)
    Path(data_directory_0, "directory_0_0").mkdir(parents=True, exist_ok=True)

    data_directory_0_file = Path(data_directory_0, "hello_world.txt")
    data_directory_0_file.write_text("Storage data")

    disk_0_data_directory = Path(
        config["mergerfs_disks_storage_path"],
        config["mergerfs_disks_names"][0],
        config["mkdir_paths"][0],
        "directory_0",
    )
    disk_0_data_directory.mkdir(parents=True, exist_ok=True)
    disk_0_data_directory_file = Path(disk_0_data_directory, "hello_world.txt")
    disk_0_data_directory_file.write_text("Disk 0 data")

    data_directory_1 = Path(
        config["mergerfs_storage_path"],
        config["mkdir_paths"][1],
        "directory_1",
    )
    data_directory_1.mkdir(parents=True, exist_ok=True)

    return data_directory_0_file, disk_0_data_directory_file


def cleanup():
    shutil.rmtree(Path(".decrypted"))


def recursive_dir_list(path):
    folder_list = []
    for root, dirs, files in os.walk(path):
        for dirname in dirs:
            dirpath = Path(Path(root, dirname).relative_to(path))
            folder_list.append(dirpath)
    return folder_list


class Test(unittest.TestCase):
    def test_mkdir(self):
        with open("config.json", "r") as config_file:
            config = json.load(config_file)

        data_directory_0_file, disk_0_data_directory_file = prepare_test(config)

        for i in range(2):
            # Run multiple time to see if it works with existing directories
            main.mergerfs_mkdir(
                mergerfs_disks_names=config["mergerfs_disks_names"],
                mergerfs_disks_storage_path=config["mergerfs_disks_storage_path"],
                mergerfs_storage_path=config["mergerfs_storage_path"],
                mkdir_paths=config["mkdir_paths"],
            )

        storage_dir_list = []
        for mkdir_path in config["mkdir_paths"]:
            storage_dir_list.append(
                recursive_dir_list(Path(config["mergerfs_storage_path"], mkdir_path))
            )
        for mergerfs_disks_name in config["mergerfs_disks_names"]:
            disk_dir_list = []
            for mkdir_path in config["mkdir_paths"]:
                disk_dir_list.append(
                    recursive_dir_list(
                        Path(
                            config["mergerfs_disks_storage_path"],
                            mergerfs_disks_name,
                            mkdir_path,
                        )
                    )
                )
            assert disk_dir_list == storage_dir_list
        # Check if dir_0 file is differnt from the one in storage since it was created manually
        assert (
            data_directory_0_file.read_text() != disk_0_data_directory_file.read_text()
        )
        cleanup()


if __name__ == "__main__":
    unittest.main()
