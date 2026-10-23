"""Data of the staging VM: staging/, over all.py"""

from deploy.common.data import load_group

globals().update(load_group("staging"))

# Just started by deploy-staging, the VM may still be booting: retry for ~10 minutes. Real
# logins, unlike polling with ssh-keyscan, which sshd's PerSourcePenalties answers by
# refusing the source for a while
ssh_connect_retries = 80
ssh_connect_retry_min_delay = 5
ssh_connect_retry_max_delay = 10
