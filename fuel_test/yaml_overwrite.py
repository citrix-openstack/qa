#!/usr/bin/env python

import argparse
import yaml


def walk_copy(src, dest, key):
    s = src[key] if key is not None else src
    d = dest[key] if key is not None else dest
    if type(s) == dict:
        for k in s:
            walk_copy(s, d, k)
    elif type(s) == list:
        for (i, v) in enumerate(s):
            walk_copy(s, d, i)
    else:
        dest[key] = src[key]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="./yaml_overwrite.py",
        description="Overwrite dest yaml with src yaml")
    parser.add_argument("src", help="")
    parser.add_argument("dest", help="")
    args = parser.parse_args()

    src = yaml.load(open(args.src))
    dest = yaml.load(open(args.dest))

    walk_copy(src, dest, None)

    with open(args.dest, "w") as f:
        f.write(yaml.safe_dump(dest))
