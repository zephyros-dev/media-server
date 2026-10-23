"""Render the jinja templates in deploy/<package>/templates the way ansible's template module
did, which they were written for"""

import os

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from deploy.common.data import REPO

_env = Environment(
    loader=FileSystemLoader(REPO / "deploy"),
    undefined=StrictUndefined,
    # Ansible's template defaults, plus the templates' `#jinja2:lstrip_blocks` header
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)
_env.filters["basename"] = os.path.basename


def render(name: str, context: dict, package="application") -> str:
    """Render `deploy/<package>/templates/<name>`"""
    source, _, _ = _env.loader.get_source(_env, f"{package}/templates/{name}")
    # Ansible reads the `#jinja2:` header line as template options and drops it
    if source.startswith("#jinja2:"):
        source = source.split("\n", 1)[1]
    return _env.from_string(source).render(context)
