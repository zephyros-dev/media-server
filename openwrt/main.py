#!/usr/local/bin/python

import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml
from dotenv import set_key

os.chdir(Path(sys.argv[0]).parent)

openwrt_config = yaml.safe_load(
    subprocess.run(
        ["sops", "-d", "config.sops.yaml"], capture_output=True, text=True
    ).stdout
)

# TODO: Download zapret with version

for router in openwrt_config["router_list"]:
    # Copy the repo
    subprocess.run(
        f"rsync -4 --mkpath --chown root:root -a --delete --exclude '.git' --exclude 'config' .decrypted.zapret/ root@{router}:/opt/zapret",
        shell=True,
    )

    # Copy tmp config
    shutil.copy(".decrypted.zapret/config.default", ".env")

    # Change the config
    for key, value in openwrt_config["config"].items():
        set_key(".env", key, value)

    # Copy the config
    subprocess.run(
        f"rsync -4 --chown root:root -a --delete .env root@{router}:/opt/zapret/config",
        shell=True,
    )

# TODO: Run non-interactive
# Run the script
# subprocess.run(
#     f"ssh root@{openwrt_config['router']} 'cd /opt/zapret && ./install_easy.sh'",
#     shell=True,
# )
