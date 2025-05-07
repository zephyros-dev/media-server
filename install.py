import argparse
import re
import subprocess
from pathlib import Path

import devcontainer
import yaml

parser = argparse.ArgumentParser(description="Setup devcontainer")
parser.add_argument(
    "--profile",
    help="profile to run, either ci or devcontainer",
    default="devcontainer",
)

args = parser.parse_args()

dependencies_version = yaml.safe_load(Path("dependencies.yaml").read_text())


def shared_setup():
    # Cue setup
    subprocess.run("cue get go k8s.io/api/core/...", shell=True, cwd="cue")

    # Install mitogen
    (Path(Path.home()) / ".ansible/plugins").mkdir(parents=True, exist_ok=True)
    mitogen_path = re.search(
        r"Location: (.+)\n",
        subprocess.run(
            "uv pip show mitogen", shell=True, capture_output=True, text=True
        ).stdout,
    ).group(1)

    # https://stackoverflow.com/questions/8299386/modifying-a-symlink-in-python/55742015#55742015
    Path(Path.home() / ".ansible/plugins/strategy_tmp").symlink_to(
        Path(mitogen_path) / "ansible_mitogen/plugins/strategy"
    )
    Path(Path.home() / ".ansible/plugins/strategy_tmp").rename(
        Path.home() / ".ansible/plugins/strategy"
    )
    subprocess.run("ansible-galaxy install -r requirements.yaml", shell=True)


if args.profile == "devcontainer":
    devcontainer.install_aqua()
    shared_setup()
    (Path.home() / ".terraformrc").write_text(
        'plugin_cache_dir = "/home/vscode/.terraform.d/plugin-cache"'
    )

    # Fix cue vscode extension
    cue_path = subprocess.run(
        "aqua which cue", shell=True, capture_output=True, text=True
    ).stdout.strip()
    cue_bin_path = Path.home() / ".local/bin/cue"
    if not cue_bin_path.is_symlink():
        cue_bin_path.symlink_to(cue_path)

if args.profile == "dagger":
    devcontainer.install_aqua()
    shared_setup()
    subprocess.run("aqua install --tags=dagger", shell=True)

if args.profile == "ci":
    devcontainer.install_aqua()
    devcontainer.install_podman()
    subprocess.run("aqua install --tags=ci", shell=True)
