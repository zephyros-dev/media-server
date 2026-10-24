"""Data of every host: the secrets and settings in all/ (ssh_user and _sudo_password
included), lowest in precedence"""

from deploy.tasks.common.data import load_group

globals().update(load_group("all"))

# The staging VM is recreated by tofu with a new host key
ssh_strict_host_key_checking = "off"
