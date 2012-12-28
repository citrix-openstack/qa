#!/bin/bash
LOCALRC="devstack/localrc"
eval `grep LOGFILE $LOCALRC`
eval `grep SCREEN_LOGDIR $LOCALRC`

tar -chzf - $SCREEN_LOGDIR $LOGFILE
