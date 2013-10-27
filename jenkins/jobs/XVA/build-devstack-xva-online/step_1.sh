#!/bin/bash
set -eux

ssh guard@silicon lock-get-single-server --reason $BUILD_URL > "${BUILD_NUMBER}.properties"
. "$(pwd)/${BUILD_NUMBER}.properties"
