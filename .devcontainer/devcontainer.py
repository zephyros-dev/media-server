import argparse
import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

import yaml

go_arch_map = {
    "x86_64": "amd64",
    "aarch64": "arm64",
}

go_arch = go_arch_map[platform.machine()]


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


def install_podman():
    if Path("dependencies.yaml").exists():
        dependencies_version = yaml.safe_load(Path("dependencies.yaml").read_text())
    else:
        dependencies_version = {}

    if "containers/podman" in dependencies_version:
        # Install latest version of podman
        podman_path = Path.home() / "bin/podman"

        PODMAN_VERSION = dependencies_version["containers/podman"]
        if check_version("docker --version", PODMAN_VERSION):
            subprocess.run(
                f"curl -Lo {Path.home() / 'podman.tar.gz'} https://github.com/containers/podman/releases/download/{PODMAN_VERSION}/podman-remote-static-linux_{go_arch}.tar.gz",
                shell=True,
            )
            subprocess.run(
                f"tar -zxvf {Path.home() / 'podman.tar.gz'} -C {Path.home()}",
                shell=True,
            )
            subprocess.run(
                f"mv {Path.home()}/bin/podman-remote-static-linux_{go_arch} {podman_path}",
                shell=True,
            )

            (Path.home() / ".local/bin").mkdir(parents=True, exist_ok=True)
            subprocess.run(
                f"ln --symbolic --force {podman_path} {Path.home()}/.local/bin/docker",
                shell=True,
            )


def install_aqua():
    # Check if aqua.yaml is present
    if (Path(os.getcwd()) / "aqua.yaml").exists():
        AQUA_VERSION = yaml.safe_load(
            Path(".devcontainer/dependencies.yaml").read_text()
        )["aquaproj/aqua"]
        aqua_bin_path = Path.home() / ".local/share/aquaproj-aqua/bin/aqua"
        aqua_bin_path.parent.mkdir(parents=True, exist_ok=True)
        if check_version("aqua --version", AQUA_VERSION):
            subprocess.run(
                f"curl -Lo {Path.home() / 'aqua.tar.gz'} https://github.com/aquaproj/aqua/releases/download/{AQUA_VERSION}/aqua_linux_{go_arch}.tar.gz",
                shell=True,
            )
            subprocess.run(
                f"tar -zxvf {Path.home() / 'aqua.tar.gz'} aqua -C {aqua_bin_path}",
                shell=True,
            )
            shutil.move("aqua", aqua_bin_path)
            os.chmod(aqua_bin_path, 0o755)

        (Path(Path.home()) / ".config/aquaproj-aqua").mkdir(parents=True, exist_ok=True)

        if not (Path.home() / ".config/aquaproj-aqua/aqua.yaml").is_symlink():
            Path(Path.home() / ".config/aquaproj-aqua/aqua.yaml").symlink_to(
                Path(os.getcwd()) / "aqua.yaml"
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Setup devcontainer")
    parser.add_argument(
        "--stage",
        help="stage to run",
        default="all",
    )

    args = parser.parse_args()

    os.chdir("../")

    if args.stage == "all" or args.stage == "onCreateCommand":
        install_podman()
        install_aqua()
        subprocess.run("aqua install --all", shell=True)

    if args.stage == "all" or args.stage == "postAttachCommand":
        if Path(".pre-commit-config.yaml").exists():
            subprocess.run(
                "git config --global init.templateDir ~/.git-template", shell=True
            )
            subprocess.run(
                "pre-commit init-templatedir -t pre-commit ~/.git-template",
                shell=True,
            )
            subprocess.run("pre-commit install", shell=True)
        if Path("install.py").exists():
            subprocess.run(["uv", "sync"])
            subprocess.run(["uv", "run", "install.py"])
