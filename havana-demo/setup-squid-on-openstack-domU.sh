#!/bin/bash

# Set up squid on the OpenStack domU, to simplify installing
# packages on VMs

apt-get -y install squid 

echo acl localnet src 10.0.0.0/8 >> /etc/squid3/squid.conf
echo http_access allow localnet >> /etc/squid3/squid.conf

service squid3 restart

