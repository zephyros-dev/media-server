import argparse
import os
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description="Setup devcontainer")
parser.add_argument(
    "--profile",
    help="profile to run, either ci or devcontainer",
    default="dev",
)

args = parser.parse_args()


def shared_setup():
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
    subprocess.run("uv run ansible-galaxy install -r requirements.yaml", shell=True)


if args.profile == "dev":
    shared_setup()
    (Path.home() / ".tofurc").write_text(
        f'plugin_cache_dir = "{Path.home()}/.terraform.d/plugin-cache"'
    )

env = os.environ.copy()

if args.profile == "ci":
    shared_setup()
    env["MISE_ENV"] = "ci"
    subprocess.run("mise install", shell=True, env=env)
