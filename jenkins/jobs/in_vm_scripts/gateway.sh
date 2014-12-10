#!/bin/bash
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
sudo sed -i /etc/shorewall/shorewall.conf \
    -e 's/IP_FORWARDING=.*/IP_FORWARDING=On/g'

# Enable shorewall on startup
sudo sed -i /etc/default/shorewall \
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
