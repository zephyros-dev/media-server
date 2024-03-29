import os
import sys

import anyio
import dagger
from helper import cue_setup, install_aqua, sops_loader


async def ci():
    async with dagger.Connection(dagger.Config(log_output=sys.stderr)) as client:
        user_dir = "/root"
        workspace = client.host().directory(".")

        ci = (
            client.container()
            .build(context=workspace, dockerfile="ci/Dockerfile")
            .with_exec(["rm", "-f", "/etc/apt/apt.conf.d/docker-clean"])
            .with_new_file(
                path="/etc/apt/apt.conf.d/keep-cache",
                contents='Binary::apt::APT::Keep-Downloaded-Packages "true";',
                permissions=644,
            )
            .with_mounted_cache(
                path="/var/cache/apt",
                cache=client.cache_volume(key="ci-cache-cache-apt"),
                sharing=dagger.CacheSharingMode.LOCKED,
            )
            .with_mounted_cache(
                path="/var/lib/apt",
                cache=client.cache_volume(key="ci-cache-lib-apt"),
                sharing=dagger.CacheSharingMode.LOCKED,
            )
            .with_exec(["apt", "update"])
            .with_exec(
                [
                    "apt",
                    "install",
                    "-y",
                    "--no-install-recommends",
                    "curl",
                    "openssh-client",
                    "openssl",
                    "rsync",
                    "sshpass",
                    "tar",
                    "whois",
                ]
            )
        )

        ci = (
            ci.with_unix_socket(
                "/ssh-agent.sock",
                client.host().unix_socket(os.getenv("SSH_AUTH_SOCK")),
            )
            .with_mounted_directory(f"{user_dir}/workspace", workspace)
            .with_workdir(f"{user_dir}/workspace")
            .with_mounted_cache(
                "/root/.cache/pip",
                cache=client.cache_volume(key="ci-cache-pip"),
                sharing=dagger.CacheSharingMode.LOCKED,
            )
            .with_exec(
                [
                    "pip",
                    "install",
                    "--no-warn-script-location",
                    "-r",
                    "ci/requirements/ci/requirements.txt",
                ]
            )
        )

        ci = await install_aqua(client, ci, user_dir)

        ci = await cue_setup(client, ci, user_dir)

        ci = (
            ci.with_mounted_cache(
                f"{user_dir}/.ansible", client.cache_volume("ansible_cache")
            )
            .with_exec(["ansible-galaxy", "install", "-r", "requirements.yaml"])
            .with_env_variable("ANSIBLE_HOST_KEY_CHECKING", "False")
        )

        ansible_config = {
            "ANSIBLE_CALLBACKS_ENABLED": "timer",
            "ANSIBLE_DISPLAY_SKIPPED_HOSTS": "False",
            "ANSIBLE_STDOUT_CALLBACK": "dense",
        }

        if os.getenv("DEBUG_MODE") == "true":
            pass
        else:
            for key, value in ansible_config.items():
                ci = ci.with_env_variable(key, value)

        ci = sops_loader(client, ci, user_dir)

        ci = ci.with_exec(["ansible-playbook", "main.yaml"])

        await ci.stdout()


if __name__ == "__main__":
    anyio.run(ci)
