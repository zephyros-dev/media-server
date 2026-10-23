"""Data of the server: server/, over all.py"""

from deploy.common.data import load_group

globals().update(load_group("server"))
