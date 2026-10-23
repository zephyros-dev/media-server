"""Start the staging VM on the server, or shut it down with `--data stop=true`. Run by the deploy-staging mise task, before the staging deploy"""

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import server

VIRSH = "virsh --connect qemu:///system"

# domstate ends with a blank line
state = host.get_fact(Command, f"{VIRSH} domstate staging").strip()
if host.data.get("stop"):
    # Like ansible's virt state=shutdown: anything not already off
    if state != "shut off":
        server.shell(
            name="Shut down the staging VM", commands=[f"{VIRSH} shutdown staging"]
        )
elif state == "paused":
    # Like ansible's virt state=running, which unpauses
    server.shell(name="Resume the staging VM", commands=[f"{VIRSH} resume staging"])
elif state != "running":
    server.shell(name="Start the staging VM", commands=[f"{VIRSH} start staging"])
