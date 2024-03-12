#!/usr/local/bin/python

import argparse
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

import requests
from jinja2 import Environment, FileSystemLoader

parser = argparse.ArgumentParser(description="Setup devcontainer")
parser.add_argument(
    "--stage",
    help="stage to run",
    default="all",
)

args = parser.parse_args()

home_path = Path("/home/vscode")


def check_version(command, desired_version):
    # Install the tools if tools is not installed or current version is different
    current_version = subprocess.run(
        command, shell=True, capture_output=True, text=True
    )
    if "not found" in current_version.stderr or re.search(
        r"\d+\.\d+\.\d+",
        current_version.stdout,
    ).group(0) != desired_version.strip("v"):
        return True
    else:
        return False


environment = Environment(
    loader=FileSystemLoader(".devcontainer/templates"), keep_trailing_newline=True
)

if args.stage == "all" or args.stage == "onCreateCommand":
    if platform.machine() == "x86_64":
        architecture = "amd64"
    elif platform.machine() == "aarch64":
        architecture = "arm64"
    aqua_bin_path = home_path / ".local/share/aquaproj-aqua/bin/aqua"
    if check_version("aqua --version", os.environ["AQUA_VERSION"]):
        print("Installing aqua")
        subprocess.run(
            f"curl -Lo {home_path / 'aqua.tar.gz'} https://github.com/aquaproj/aqua/releases/download/{os.environ['AQUA_VERSION']}/aqua_linux_{architecture}.tar.gz",
            shell=True,
        )
        subprocess.run(
            f"tar -zxvf {home_path / 'aqua.tar.gz'} aqua -C {aqua_bin_path}", shell=True
        )
        shutil.move("aqua", aqua_bin_path)
        os.chmod(aqua_bin_path, 0o755)

    (Path(home_path) / ".config/aquaproj-aqua").mkdir(parents=True, exist_ok=True)

    if not (home_path / ".config/aquaproj-aqua/config.yaml").is_symlink():
        Path(home_path / ".config/aquaproj-aqua/config.yaml").symlink_to(
            Path("aqua.yaml")
        )

    subprocess.run("aqua install --all", shell=True)

    # Install latest version of podman
    podman_path = f"{home_path}/bin/podman"

    if check_version("podman --version", os.environ["PODMAN_VERSION"]):
        subprocess.run(
            f"curl -Lo {home_path / 'podman.tar.gz'} https://github.com/containers/podman/releases/download/{os.environ['PODMAN_VERSION']}/podman-remote-static-linux_{architecture}.tar.gz",
            shell=True,
        )
        subprocess.run(
            f"tar -zxvf {home_path / 'podman.tar.gz'} -C {home_path}", shell=True
        )
        subprocess.run(
            f"sudo mv {home_path}/bin/podman-remote-static-linux_{architecture} {podman_path}",
            shell=True,
        )

    subprocess.run(f"sudo ln -s {podman_path} /usr/local/bin/docker", shell=True)

    # Fix cue vscode extension
    cue_path = subprocess.run(
        "aqua which cue", shell=True, capture_output=True, text=True
    ).stdout.strip()
    cue_home_path = home_path / ".local/bin/cue"
    if not cue_home_path.is_symlink():
        cue_home_path.symlink_to(cue_path)

    subprocess.run("cue get go k8s.io/api/...", shell=True, cwd="cue")

    # Guix
    template = environment.get_template("channels.scm.j2")
    Path(home_path / ".config/guix/channels.scm").write_text(template.render())
    # Emacs
    (Path(home_path) / ".config/emacs").mkdir(parents=True, exist_ok=True)
    template = environment.get_template("init.el.j2")
    (Path(home_path) / ".config/emacs/init.el").write_text(template.render())

if args.stage == "all" or args.stage == "postAttachCommand":
    subprocess.run("git config --global init.templateDir ~/.git-template", shell=True)
    subprocess.run(
        "pre-commit init-templatedir -t pre-commit ~/.git-template", shell=True
    )
    subprocess.run("ansible-galaxy install -r requirements.yaml", shell=True)
    gitignore_list = [
        "ansible",
        "dotenv",
        "go",
        "intellij+all",
        "node",
        "python",
        "terraform",
        "VisualStudioCode",
    ]

    git_ignore_remote = requests.get(
        f"https://www.toptal.com/developers/gitignore/api/{','.join(gitignore_list)}"
    )

    template = environment.get_template(".gitignore.j2")
    Path(".gitignore").write_text(
        template.render(git_ignore_template=git_ignore_remote.text)
    )

    (Path(home_path) / ".terraformrc").write_text(
        'plugin_cache_dir = "~/.terraform.d/plugin-cache"'
    )

    subprocess.run("pre-commit install", shell=True)

    guix_env = """
GUIX_PROFILE="$HOME/.config/.guix/current"
. "$GUIX_PROFILE/etc/profile"
          """
    Path(home_path / ".zshenv").write_text(guix_env)
