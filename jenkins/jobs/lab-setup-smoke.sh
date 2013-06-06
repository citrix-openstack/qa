#!/bin/bash
set -eu
function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 DEVBOX

Using your mini-lab, setup smokestack.

Positional arguments:
  DEVBOX    - Address of your devbox
USAGE
exit 1
}

DEVBOX=${1-$(print_usage_and_quit)}

set -x
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
BUILDDIR=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)

cat "$BUILDDIR/install-smoke.sh" | "$REMOTELIB/bash.sh" "ubuntu@$DEVBOX"
