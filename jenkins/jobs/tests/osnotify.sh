#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
wget -qO - https://raw.github.com/citrix-openstack/osnotify/master/setup.sh | bash -s -- ci
