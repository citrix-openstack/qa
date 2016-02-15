#!/usr/bin/env python

import argparse
import yaml
import itertools


def configure_interfaces(ifaces, actions):
    """
    In node_X/interfaces.yaml, property assigned_networks of interfaces is
    used to decide the network cabling and originally might like this:

    - assigned_networks:
      - {id: 1, name: fuelweb_admin}
      - {id: 3, name: management}
      - {id: 4, name: storage}
      - {id: 5, name: fixed}
      ...
    - assigned_networks:
      - {id: 2, name: public}
      ...
    - assigned_networks:
      ...

    As you see, id is not fixed. So to reassign the networks, we setup a map
    using node_interfaces.yaml like below to manipulate node_X/interfaces.yaml

    eth0:
    - fuelweb_admin
    eth1:
    - public
    - management
    - storage
    eth2:
    - fixed

    Finally we are supposed to make node_X/interfaces.yaml like:

    - assigned_networks:
      - {id: 1, name: fuelweb_admin}
      ...
    - assigned_networks:
      - {id: 2, name: public}
      - {id: 3, name: management}
      - {id: 4, name: storage}
      ...
    - assigned_networks:
      - {id: 5, name: fixed}
      ...

    """
    all_networks = [iface["assigned_networks"] for iface in ifaces]
    all_networks = list(itertools.chain(*all_networks))
    for iface_name in actions:
        network_names = actions[iface_name]
        networks = [network for network in all_networks
                    if network["name"] in network_names]
        iface = [iface for iface in ifaces if iface["name"] == iface_name][0]
        iface["assigned_networks"] = networks


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="./configure_interfaces.py",
        description="Configure node interfaces with networks")
    parser.add_argument("interfaces", help="")
    parser.add_argument("actions", help="")
    args = parser.parse_args()

    ifaces = yaml.load(open(args.interfaces))
    actions = yaml.load(open(args.actions))

    configure_interfaces(ifaces, actions)

    with open(args.interfaces, "w") as f:
        f.write(yaml.safe_dump(ifaces))
