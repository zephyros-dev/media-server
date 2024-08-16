#!/usr/local/bin/python

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from dotenv import set_key

os.chdir(Path(sys.argv[0]).parent)

openwrt_config = json.loads(
    subprocess.run(["sops", "-d", "config.sops.json"], capture_output=True).stdout
)

for router in openwrt_config["router_list"]:
    # Copy the repo
    subprocess.run(
        f"rsync -4 --mkpath --chown root:root -a --delete --exclude '.git' --exclude 'config' ../submodules/zapret/ root@{router}:/opt/zapret",
        shell=True,
    )

    # Copy tmp config
    shutil.copy("../submodules/zapret/config.default", ".env")

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
