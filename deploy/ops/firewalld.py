"""firewalld services, like ansible.posix.firewalld with permanent and immediate"""

from pyinfra import host
from pyinfra.api import FactBase, operation


class Services(FactBase):
    """Services enabled in the default zone, the permanent or the runtime config"""

    def command(self, permanent: bool):
        return "firewall-cmd --list-services" + (" --permanent" if permanent else "")

    def process(self, output):
        return " ".join(output).split()


@operation()
def service(service: str):
    """Enable `service` in the default zone, now and across reloads"""
    for permanent in (True, False):
        if service not in host.get_fact(Services, permanent=permanent):
            yield f"firewall-cmd --add-service={service}" + (
                " --permanent" if permanent else ""
            )
