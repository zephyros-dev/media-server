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

version = yaml.safe_load(Path("../dependencies.yaml").read_text())["bol-van/zapret"]
if not Path(f".decrypted.zapret/zapret-{version}").exists():
    print(f"New version detected {version}")
    url = f"https://github.com/bol-van/zapret/releases/download/{version}/zapret-{version}-openwrt-embedded.tar.gz"
    subprocess.run(
        f"curl -Lo .decrypted.zapret.tar.gz {url}",
        shell=True,
    )
    Path(".decrypted.zapret").mkdir(parents=True, exist_ok=True)
    subprocess.run(
        "tar -zxvf .decrypted.zapret.tar.gz -C .decrypted.zapret", shell=True
    )

# Need to create custom user include list since headless service fail those domain during the first call and do not retry for autohostlist
# https://github.com/bol-van/zapret/blob/master/docs/readme.en.md#autohostlist-mode
Path(f".decrypted.zapret/zapret-{version}/ipset/zapret-hosts-user.txt").write_text(
    openwrt_config["custom_user_include"]
)

for router in openwrt_config["router_list"]:
    # Copy the repo
    subprocess.run(
        f"rsync -4 --mkpath --chown root:root -a --delete --exclude '.git' --exclude 'config' .decrypted.zapret/zapret-{version}/ root@{router}:/opt/zapret",
        shell=True,
    )

    # Copy tmp config
    shutil.copy(f".decrypted.zapret/zapret-{version}/config.default", ".env")

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
