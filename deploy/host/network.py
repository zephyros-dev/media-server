"""Hostname, the bridge0 network, firewalld services and the staging DNS record"""

import json
import urllib.request

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import python, server

from deploy.common.facts import host_vars
from deploy.ops import firewalld, nmcli

FIREWALL_SERVICES = [
    "http",
    "http3",
    "https",
    "samba",
    "syncthing",
    "transmission-client",
]
WOL = {
    "802-3-ethernet.wake-on-lan": "magic",
    "802-3-ethernet.auto-negotiate": "yes",
}
PORKBUN_API = "https://api.porkbun.com/api/json/v3"


def deploy():
    v = host_vars()
    interface = v["physical_interface"]

    server.hostname(
        name="Set the hostname", hostname=v["specificed_hostname"], _sudo=True
    )
    nmcli.connection(
        name="Bridge bridge0",
        con_name="bridge0",
        type="bridge",
        # bridge.priority: ansible's nmcli module always sent its default 128, where a bridge
        # NetworkManager creates gets 32768
        settings={"ipv6.addr-gen-mode": "eui64", "bridge.priority": "128", **WOL},
        _sudo=True,
    )
    nmcli.connection(
        name=f"{interface} as a port of bridge0",
        con_name=interface,
        type="ethernet",
        settings={
            "connection.slave-type": "bridge",
            "connection.master": "bridge0",
            "bridge-port.hairpin-mode": "no",
            **WOL,
        },
        _sudo=True,
    )
    for service in FIREWALL_SERVICES:
        firewalld.service(
            name=f"Allow {service} in firewalld", service=service, _sudo=True
        )

    if v["host"]["hostname"] == "staging":
        _staging_dns(v)


def _porkbun(v: dict, path: str, **body) -> dict:
    request = urllib.request.Request(
        f"{PORKBUN_API}/{path}",
        data=json.dumps(
            {
                "apikey": v["porkbun_api_key"],
                "secretapikey": v["porkbun_api_secret_key"],
                **body,
            }
        ).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def _staging_dns(v: dict):
    """`*.staging.<root_domain>` A record pointing at the VM, like sdorra.porkbun"""
    # Source address of the default route, like ansible's default_ipv4
    route = host.get_fact(Command, "ip -4 route get 1.1.1.1").split()
    address = route[route.index("src") + 1]
    domain = v["root_domain"]
    path = f"dns/{{}}/{domain}/A/*.staging"

    # Read at deploy time, so --dry shows whether the record changes
    records = _porkbun(v, path.format("retrieveByNameType"))["records"]
    if [r["content"] for r in records] == [address]:
        return
    if records:
        python.call(
            name="Update the *.staging DNS record",
            function=lambda: _porkbun(
                v, path.format("editByNameType"), content=address
            ),
        )
    else:
        python.call(
            name="Create the *.staging DNS record",
            function=lambda: _porkbun(
                v, f"dns/create/{domain}", name="*.staging", type="A", content=address
            ),
        )
