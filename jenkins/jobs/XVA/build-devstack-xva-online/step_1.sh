#!/bin/bash
set -eux

sh guard@silicon lock-get-single-server --reason $BUILD_URL > "${BUILD_NUMBER}.properties"
. "$(pwd)/${BUILD_NUMBER}.properties"
