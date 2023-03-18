import os


def sops_loader(client, ci, user_dir):
    secret_sops_env = client.host().env_variable("SOPS_AGE_KEY").secret()
    age_key_path = f"{os.environ['HOME']}/.config/sops/age/keys.txt"
    if os.path.exists(age_key_path):
        return ci.with_mounted_directory(
            f"{user_dir}/.config/sops/age",
            client.host().directory(os.path.dirname(age_key_path)),
        )
    else:
        return ci.with_secret_variable("SOPS_AGE_KEY", secret_sops_env)


async def install_aqua(client, ci, user_dir):
    AQUA_INSTALLER_VERSION = "2.0.2"
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
                "aqua-installer",
                f"https://raw.githubusercontent.com/aquaproj/aqua-installer/v{AQUA_INSTALLER_VERSION}/aqua-installer",  # noqa
            ]
        )
        .with_exec(["chmod", "+x", "aqua-installer"])
        .with_exec(["./aqua-installer"])
        .with_exec(["aqua", "install"])
    )
