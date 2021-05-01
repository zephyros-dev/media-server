#!/bin/bash
echo -n "Encrypt or decrypt (0 or 1): "
read action

if [ $action -eq 0 ]; then
{
    ansible-vault encrypt --vault-id container@../../inventory/container_secret \
    ./vault.yaml
}
elif [ $action -eq 1 ]; then
{
    ansible-vault decrypt --vault-id container@../../inventory/container_secret \
    ./vault.yaml
}
else
{
    echo "Wrong input. 0 or 1 only."
}
fi