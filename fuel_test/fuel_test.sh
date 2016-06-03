#!/bin/bash

set -eu

timeout 30m ./prep_env.sh
[ $? -ne 0 ] && echo prep_env execution timeout && exit -1
timeout 90m ./deploy_env.sh
[ $? -ne 0 ] && echo deploy_env execution timeout && exit -1
timeout 15m ./test_env.sh
[ $? -ne 0 ] && echo test_env execution timeout && exit -1