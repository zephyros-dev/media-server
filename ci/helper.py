import os
import platform

import dagger


def sops_loader(client: dagger.Client, ci: dagger.Container, user_dir):
    secret_sops_env = client.host().env_variable("SOPS_AGE_KEY").secret()
    age_key_path = f"{os.environ['HOME']}/.config/sops/age/keys.txt"
    if os.path.exists(age_key_path):
        return ci.with_mounted_directory(
            f"{user_dir}/.config/sops/age",
            client.host().directory(os.path.dirname(age_key_path)),
        )
    else:
        return ci.with_secret_variable("SOPS_AGE_KEY", secret_sops_env)


async def install_aqua(client: dagger.Client, ci: dagger.Container, user_dir):
    AQUA_VERSION = "v2.6.0"
    if platform.machine() == "x86_64":
        MACHINE = "amd64"
    elif platform.machine() == "aarch64":
        MACHINE = "arm64"
    print(MACHINE)
    container_path = await ci.env_variable("PATH")
    return (
        ci.with_env_variable(
            "PATH", f"/root/.local/share/aquaproj-aqua/bin:{container_path}"
        )
        .with_mounted_cache(
            f"{user_dir}/.local/share/aquaproj-aqua/pkgs",
            client.cache_volume("aqua-pkgs"),
        )
        .with_mounted_cache(
            f"{user_dir}/.local/share/aquaproj-aqua/registries",
            client.cache_volume("aqua-registries"),
        )
        .with_exec(
            [
                "curl",
                "-Lo",
                "aqua.tar.gz",
                f"https://github.com/aquaproj/aqua/releases/download/{AQUA_VERSION}/aqua_linux_{MACHINE}.tar.gz",  # noqa
            ]
        )
        .with_exec(["tar", "-xzf", "aqua.tar.gz"])
        .with_exec(["mkdir", "-p", "/root/.local/share/aquaproj-aqua/bin"])
        .with_exec(["mv", "aqua", "/root/.local/share/aquaproj-aqua/bin/aqua"])
        .with_exec(["aqua", "install"])
    )
