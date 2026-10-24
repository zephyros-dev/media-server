"""Data of the OpenWrt routers: openwrt/, over all.py"""

from deploy.common.data import load_group

globals().update(load_group("openwrt"))

# Not the server's login from all.py
ssh_user = "root"
# dropbear has no sftp-server, but it comes with scp
ssh_file_transfer_protocol = "scp"
