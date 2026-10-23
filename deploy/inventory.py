"""The hosts, one group each. Their data is in group_data/<group>.py, which pyinfra loads
from next to this file"""

import socket


def _ipv4(hostname: str) -> str:
    # IPv4 only, like `ssh -4`. A host that doesn't resolve yet (staging VM off) keeps its name
    try:
        return socket.getaddrinfo(hostname, 22, socket.AF_INET)[0][4][0]
    except socket.gaierror:
        return hostname


server = [("server.lan", {"ssh_hostname": _ipv4("server.lan")})]
staging = [("staging.lan", {"ssh_hostname": _ipv4("staging.lan")})]
