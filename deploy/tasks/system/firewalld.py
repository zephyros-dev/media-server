"""firewalld services, like ansible.posix.firewalld with permanent and immediate"""

from pyinfra import host
from pyinfra.api import FactBase, operation


class Services(FactBase):
    """Services enabled in the default zone, the permanent or the runtime config"""

    def command(self, permanent: bool):
        return "firewall-cmd --list-services" + (" --permanent" if permanent else "")

    def process(self, output):
        return " ".join(output).split()


# pyinfra doesn't cache facts, and firewall-cmd is slow: look each list up once. All the
# operations are prepared before any runs, so it can't go stale during the deploy
_services: dict[tuple[str, bool], list[str]] = {}


def _enabled(permanent: bool) -> list[str]:
    key = (host.name, permanent)
    if key not in _services:
        _services[key] = host.get_fact(Services, permanent=permanent)
    return _services[key]


@operation()
def service(service: str):
    """Enable `service` in the default zone, now and across reloads"""
    for permanent in (True, False):
        if service not in _enabled(permanent):
            yield f"firewall-cmd --add-service={service}" + (
                " --permanent" if permanent else ""
            )
