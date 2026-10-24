"""NetworkManager connection profiles, the part of community.general.nmcli in use"""

from pyinfra import host
from pyinfra.api import FactBase, QuoteString, StringCommand, operation


class Connection(FactBase):
    """`{setting: value}` of a connection profile, empty when there's no such profile"""

    def command(self, con_name: str, fields: list[str]):
        return StringCommand(
            "nmcli",
            "--terse",
            "--fields",
            ",".join(fields),
            "connection",
            "show",
            QuoteString(con_name),
            "2>/dev/null || true",
        )

    def process(self, output):
        # --terse escapes ':' inside values as '\:'
        return {
            key: value.replace("\\:", ":")
            for key, value in (line.split(":", 1) for line in output)
        }


@operation()
def connection(con_name: str, type: str, settings: dict[str, str]):
    """Create the profile `con_name` (its interface has the same name) or modify the settings
    that differ. Like ansible, a modified profile isn't re-activated

    + type: e.g. bridge, ethernet
    + settings: nmcli setting names to values, e.g. {"connection.master": "bridge0"}
    """
    current = host.get_fact(Connection, con_name=con_name, fields=sorted(settings))
    if not current:
        args = [QuoteString(arg) for item in settings.items() for arg in item]
        yield StringCommand(
            "nmcli",
            "connection",
            "add",
            "type",
            type,
            "con-name",
            QuoteString(con_name),
            "ifname",
            QuoteString(con_name),
            *args,
        )
        return

    changed = {k: v for k, v in settings.items() if current.get(k) != v}
    if changed:
        args = [QuoteString(arg) for item in changed.items() for arg in item]
        yield StringCommand(
            "nmcli", "connection", "modify", QuoteString(con_name), *args
        )
