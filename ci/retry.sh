#!/usr/bin/env bash

# Wireguard: For the vpn local dns lookup to work, disable `Network > DHCP and DNS > Filter > Localise queries`
wg-quick down wg0 && wg-quick up wg0 &> /dev/null
