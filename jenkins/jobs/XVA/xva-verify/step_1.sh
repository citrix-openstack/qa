#!/bin/bash
set -eux

ssh guard@silicon lock-get-single-server > "${BUILD_NUMBER}.properties"
