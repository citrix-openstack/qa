#!/usr/bin/env python

import argparse
import yaml
import itertools


def configure_interfaces(ifaces, actions):
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
