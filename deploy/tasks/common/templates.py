"""Render the jinja templates in deploy/<package>/templates the way ansible's template module
did, which they were written for"""

import base64
import hashlib
import os

import bcrypt
from jinja2 import Environment, FileSystemLoader, StrictUndefined

from deploy.tasks.common.data import REPO

_env = Environment(
    loader=FileSystemLoader(REPO / "deploy"),
    undefined=StrictUndefined,
    # Ansible's template defaults, plus the templates' `#jinja2:lstrip_blocks` header
    trim_blocks=True,
    lstrip_blocks=True,
    keep_trailing_newline=True,
)
_env.filters["basename"] = os.path.basename


def render(name: str, context: dict, package="tasks/application") -> str:
    """Render `deploy/<package>/templates/<name>`"""
    source, _, _ = _env.loader.get_source(_env, f"{package}/templates/{name}")
    # Ansible reads the `#jinja2:` header line as template options and drops it
    if source.startswith("#jinja2:"):
        source = source.split("\n", 1)[1]
    return _env.from_string(source).render(context)


_BCRYPT_ALPHABET = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
_BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


def caddy_password_hash(password: str, salt_seed: str) -> str:
    """The bcrypt hash caddy's basic_auth wants, base64 encoded like it reads it. The salt
    comes from `salt_seed` instead of being random, so the Caddyfile (and with it the caddy
    manifest) only changes when the password does, not on every deploy"""
    raw = hashlib.sha256(salt_seed.encode()).digest()[:16]
    encoded = base64.b64encode(raw).decode().rstrip("=")
    salt = encoded.translate(str.maketrans(_BASE64_ALPHABET, _BCRYPT_ALPHABET))
    hashed = bcrypt.hashpw(password.encode(), f"$2b$14${salt}".encode())
    return base64.b64encode(hashed).decode()
