#!/bin/bash
set -eux

THISDIR="$(cd "$(dirname $0)" && pwd)"

$THISDIR/../generate_parameters_for_xva_build_online.sh daily ${BUILD_NUMBER}.sh
