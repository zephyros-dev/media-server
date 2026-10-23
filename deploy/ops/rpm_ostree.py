"""rpm-ostree layered packages, like community.general.rpm_ostree_pkg"""

import json

from pyinfra import host
from pyinfra.api import FactBase, operation


class RequestedPackages(FactBase):
    """Packages layered on the default deployment, the staged one if there is one"""

    def command(self):
        return "rpm-ostree status --json"

    def process(self, output):
        return json.loads("\n".join(output))["deployments"][0]["requested-packages"]


@operation()
def packages(packages: list[str]):
    """Layer the missing `packages`. They're only usable after a reboot"""
    missing = [p for p in packages if p not in host.get_fact(RequestedPackages)]
    if missing:
        yield f"rpm-ostree install --idempotent --allow-inactive {' '.join(missing)}"
