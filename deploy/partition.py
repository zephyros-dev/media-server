"""Partition and format the disks of `disks`. Check with --dry first:
uv run pyinfra deploy/inventory.py deploy/partition.py --limit server --dry"""

from deploy.host import partition

partition.deploy()
