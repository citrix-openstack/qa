#!/bin/bash
set -eu

sed \
    -e '/^UBUNTU_INST_HTTP.*$/d'
