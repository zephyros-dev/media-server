import socket

from deploy.common.data import host_data


def _ipv4(hostname: str) -> str:
    # Same as ansible's `ssh -4`. A host that doesn't resolve yet (staging VM off) keeps its name
    try:
        return socket.getaddrinfo(hostname, 22, socket.AF_INET)[0][4][0]
    except socket.gaierror:
        return hostname


def _host(hostname: str, group: str):
    data = host_data([group])
    return (
        hostname,
        {
            **data,
            "ssh_hostname": _ipv4(hostname),
            "ssh_user": data["ansible_user"],
            # The staging VM is recreated by tofu with a new host key
            "ssh_strict_host_key_checking": "off",
            "_sudo_password": data["ansible_become_pass"],
        },
    )


server = [_host("server.lan", "server")]
staging = [_host("staging.lan", "staging")]
