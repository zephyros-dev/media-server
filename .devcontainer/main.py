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

if args.stage == "all" or args.stage == "onCreateCommand":
    aqua_bin_path = home_path / ".local/share/aquaproj-aqua/bin/aqua"
    aqua_version = subprocess.run(
        "aqua --version", shell=True, capture_output=True, text=True
    )
    if "not found" in aqua_version.stderr or re.search(
        r"\d+\.\d+\.\d+",
        aqua_version.stdout,
    ).group(0) != os.environ["AQUA_VERSION"].strip("v"):
        print("Installing aqua")
        if platform.machine() == "x86_64":
            aqua_architecture = "amd64"
        elif platform.machine() == "aarch64":
            aqua_architecture = "arm64"
        subprocess.run(
            f"curl -Lo {home_path / 'aqua.tar.gz'} https://github.com/aquaproj/aqua/releases/download/{os.environ['AQUA_VERSION']}/aqua_linux_{aqua_architecture}.tar.gz",
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
    subprocess.run("cue get go k8s.io/api/...", shell=True, cwd="cue")

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

    environment = Environment(loader=FileSystemLoader(".devcontainer/templates"), keep_trailing_newline=True)
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
