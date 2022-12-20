import os
import sys

import anyio
import dagger


async def ci():
    async with dagger.Connection(
        dagger.Config(log_output=sys.stderr, execute_timeout=None)
    ) as client:
        user_dir = "/root"
        workspace = client.host().directory(".")

        secret_sops_env = await client.host().env_variable("SOPS_AGE_KEY").secret().id()
        secret_ssh_key = (
            await client.host().env_variable("SSH_PRIVATE_KEY").secret().plaintext()
        )
        ci = (
            client.container()
            .build(context=workspace, dockerfile="Dockerfile")
            .with_unix_socket(
                "/ssh-agent.sock",
                client.host().unix_socket(
                    await client.host().env_variable("SSH_AUTH_SOCK").value()
                ),
            )
            .with_new_file(f"{user_dir}/.ssh/id_ed25519", secret_ssh_key + "\n")
            .with_exec(["chmod", "600", f"{user_dir}/.ssh/id_ed25519"])
            .with_mounted_directory(f"{user_dir}/workspace", workspace)
            .with_workdir(f"{user_dir}/workspace")
        )

        age_key_path = f"{os.environ['HOME']}/.config/sops/age/keys.txt"
        if os.path.exists(age_key_path):
            ci = ci.with_mounted_directory(
                f"{user_dir}/.config/sops/age",
                client.host().directory(os.path.dirname(age_key_path)),
            )
        else:
            ci = ci.with_secret_variable("SOPS_AGE_KEY", secret_sops_env)

        ci = (
            ci.with_mounted_cache(
                f"{user_dir}/.ansible", client.cache_volume("ansible_cache")
            )
            .with_exec(["ansible-galaxy", "install", "-r", "requirements.yaml"])
            .with_env_variable("ANSIBLE_HOST_KEY_CHECKING", "False")
            .with_env_variable(
                "ANSIBLE_NO_LOG",
                await client.host().env_variable("ANSIBLE_NO_LOG").value(),
            )
            .with_exec(["ansible-playbook", "main.yaml"])
        )

        await ci.stdout()


if __name__ == "__main__":
    anyio.run(ci)
