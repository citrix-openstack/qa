#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Create a devbox on a XenServer - a router ubuntu VM

positional arguments:
 XENSERVERNAME     The name of the XenServer
 NETNAME           The name of the network to use
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"
NETNAME="${2-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME" "1=$NETNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_ROUTER_SETUP
set -eux

sudo tee /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
address 192.168.32.1
netmask 255.255.255.0
EOF

sudo ifup eth1

export DEBIAN_FRONTEND=noninteractive

sudo apt-get -qy update
sudo apt-get -qy upgrade
sudo apt-get -qy install shorewall

sudo tee /etc/shorewall/interfaces << EOF
net      eth0           detect          dhcp,tcpflags,nosmurfs
lan      eth1           detect          dhcp
EOF

sudo tee /etc/shorewall/zones << EOF
fw      firewall
net     ipv4
lan     ipv4
EOF

sudo tee /etc/shorewall/policy << EOF
lan             net             ACCEPT
lan             fw              ACCEPT
fw              net             ACCEPT
fw              lan             ACCEPT
net             all             DROP
all             all             REJECT          info
EOF

sudo tee /etc/shorewall/rules << EOF
ACCEPT  net                     fw      tcp     22
EOF


sudo tee /etc/shorewall/masq << EOF
eth0 eth1
EOF

# Turn on IP forwarding
sudo sed -i /etc/shorewall/shorewall.conf \\
    -e 's/IP_FORWARDING=.*/IP_FORWARDING=On/g'

# Enable shorewall on startup
sudo sed -i /etc/default/shorewall \\
    -e 's/startup=.*/startup=1/g'

sudo RUNLEVEL=1 apt-get install -qy dnsmasq

# Configure dnsmasq
sudo tee -a /etc/dnsmasq.conf << EOF
interface=eth1
dhcp-range=192.168.32.50,192.168.32.150,12h
bind-interfaces
EOF

sudo service shorewall start
sudo service dnsmasq start
END_OF_ROUTER_SETUP
