#!/bin/bash
set -eux

xe vm-uninstall vm=slave force=true || true
